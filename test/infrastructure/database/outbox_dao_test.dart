import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/database/tables/outbox_table.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late FixedClock clock;

  setUp(() {
    database = openTestDatabase();
    clock = FixedClock(testEpoch);
  });

  tearDown(() => database.close());

  Future<void> enqueue(String id, {String? scopeId}) {
    return database.outboxDao.enqueue(
      id: id,
      command: 'message:send',
      payload: '{"body":"hi"}',
      scopeId: scopeId,
      now: clock(),
    );
  }

  group('enqueue', () {
    test('stores a pending entry due immediately', () async {
      await enqueue('o1');

      final due = await database.outboxDao.due(now: clock());

      expect(due, hasLength(1));
      expect(due.single.status, OutboxStatus.pending);
      expect(due.single.attempts, 0);
    });

    test('ignores a re-enqueue of the same id', () async {
      await enqueue('o1');
      await enqueue('o1');

      // Re-enqueuing the same id is the same intent, not a second one --
      // otherwise a double tap sends the message twice.
      expect(await database.outboxDao.due(now: clock()), hasLength(1));
    });
  });

  group('claim', () {
    test('marks an entry in-flight and increments its attempt count', () async {
      await enqueue('o1');

      final claimed = await database.outboxDao.claim('o1', now: clock());
      final entry = await database.outboxDao.find('o1');

      expect(claimed, isTrue);
      expect(entry!.status, OutboxStatus.inFlight);
      expect(entry.attempts, 1);
    });

    test('refuses a second claim of the same entry', () async {
      await enqueue('o1');

      final first = await database.outboxDao.claim('o1', now: clock());
      final second = await database.outboxDao.claim('o1', now: clock());

      // The `status = pending` predicate is the lock. Without it two drains
      // would both send the same command.
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('an in-flight entry is not returned as due', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());

      expect(await database.outboxDao.due(now: clock()), isEmpty);
    });
  });

  group('backoff', () {
    test('a retry scheduled in the future is not yet due', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());

      await database.outboxDao.scheduleRetry(
        'o1',
        nextAttemptAt: clock().add(const Duration(minutes: 5)),
        now: clock(),
        error: 'TIMEOUT',
      );

      expect(await database.outboxDao.due(now: clock()), isEmpty);
    });

    test('becomes due once the backoff has elapsed', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());

      await database.outboxDao.scheduleRetry(
        'o1',
        nextAttemptAt: clock().add(const Duration(minutes: 5)),
        now: clock(),
      );

      clock.advance(const Duration(minutes: 6));

      expect(await database.outboxDao.due(now: clock()), hasLength(1));
    });

    test('a scheduled retry keeps its attempt count', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());
      await database.outboxDao.scheduleRetry(
        'o1',
        nextAttemptAt: clock(),
        now: clock(),
      );

      // The count is what the attempt cap is measured against, so resetting it
      // here would make a failing entry retry forever.
      expect((await database.outboxDao.find('o1'))!.attempts, 1);
    });
  });

  group('failure', () {
    test('marks an entry failed and stops it being due', () async {
      await enqueue('o1');
      await database.outboxDao.markFailed(
        'o1',
        now: clock(),
        error: 'FORBIDDEN',
      );

      final entry = await database.outboxDao.find('o1');

      expect(entry!.status, OutboxStatus.failed);
      expect(entry.lastError, 'FORBIDDEN');
      expect(await database.outboxDao.due(now: clock()), isEmpty);
    });

    test('keeps the row so the user can retry by hand', () async {
      await enqueue('o1');
      await database.outboxDao.markFailed('o1', now: clock());

      // A dropped mutation the user never hears about is worse than a visible
      // failure.
      expect(await database.outboxDao.find('o1'), isNotNull);
    });

    test('resetForRetry clears the attempt count and requeues', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());
      await database.outboxDao.markFailed('o1', now: clock(), error: 'X');

      await database.outboxDao.resetForRetry('o1', now: clock());

      final entry = await database.outboxDao.find('o1');

      expect(entry!.status, OutboxStatus.pending);
      expect(entry.attempts, 0);
      expect(entry.lastError, isNull);
      expect(await database.outboxDao.due(now: clock()), hasLength(1));
    });
  });

  group('crash recovery', () {
    test('returns in-flight entries to pending at start-up', () async {
      await enqueue('o1');
      await database.outboxDao.claim('o1', now: clock());

      final recovered = await database.outboxDao.recoverInFlight(now: clock());

      // An in-flight row means the process died mid-send. The command may or
      // may not have landed, which is exactly what the idempotency key covers,
      // so retrying is safe and dropping it is not.
      expect(recovered, 1);
      expect(
        (await database.outboxDao.find('o1'))!.status,
        OutboxStatus.pending,
      );
    });

    test('leaves acknowledged entries alone', () async {
      await enqueue('o1');
      await database.outboxDao.markAcknowledged('o1', now: clock());

      await database.outboxDao.recoverInFlight(now: clock());

      expect(
        (await database.outboxDao.find('o1'))!.status,
        OutboxStatus.acknowledged,
      );
    });
  });

  group('ordering and scoping', () {
    test('returns due entries oldest first', () async {
      await enqueue('second');
      clock.advance(const Duration(minutes: 1));
      await enqueue('third');
      clock.now = testEpoch.subtract(const Duration(minutes: 1));
      await enqueue('first');

      clock.now = testEpoch.add(const Duration(hours: 1));
      final due = await database.outboxDao.due(now: clock());

      expect(due.map((e) => e.id), <String>['first', 'second', 'third']);
    });

    test('watchUnsettled filters by scope', () async {
      await enqueue('a', scopeId: 'c1');
      await enqueue('b', scopeId: 'c2');

      final rows = await database.outboxDao.watchUnsettled(scopeId: 'c1').first;

      expect(rows.map((e) => e.id), <String>['a']);
    });

    test('watchUnsettled excludes acknowledged entries', () async {
      await enqueue('a');
      await enqueue('b');
      await database.outboxDao.markAcknowledged('a', now: clock());

      final rows = await database.outboxDao.watchUnsettled().first;

      expect(rows.map((e) => e.id), <String>['b']);
    });

    test('watchUnsettled re-emits when an entry settles', () async {
      await enqueue('a');

      final emissions = <int>[];
      final subscription = database.outboxDao.watchUnsettled().listen(
        (rows) => emissions.add(rows.length),
      );

      await pumpEventQueue();
      await database.outboxDao.markAcknowledged('a', now: clock());
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, containsAllInOrder(<int>[1, 0]));
    });
  });

  group('pruning', () {
    test('drops acknowledged entries older than the cutoff', () async {
      await enqueue('old');
      await database.outboxDao.markAcknowledged('old', now: clock());

      final removed = await database.outboxDao.pruneCompleted(
        before: clock().add(const Duration(days: 1)),
      );

      expect(removed, 1);
      expect(await database.outboxDao.find('old'), isNull);
    });

    test('keeps unsettled entries however old', () async {
      await enqueue('pending');

      await database.outboxDao.pruneCompleted(
        before: clock().add(const Duration(days: 365)),
      );

      expect(await database.outboxDao.find('pending'), isNotNull);
    });
  });
}
