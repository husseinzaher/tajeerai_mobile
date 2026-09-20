import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/database/tables/sync_state_table.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase database;
  late FixedClock clock;

  const scope = 'conversations';

  setUp(() {
    database = openTestDatabase();
    clock = FixedClock(testEpoch);
  });

  tearDown(() => database.close());

  group('cursor', () {
    test(
      'is null before the first sync, which means a full first pass',
      () async {
        expect(await database.syncDao.cursorFor(scope), isNull);
      },
    );

    test('advances only on a confirmed success', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 3));

      await database.syncDao.markSynchronized(
        scope,
        syncedAt: serverTime,
        now: clock(),
      );

      expect(await database.syncDao.cursorFor(scope), serverTime);
    });

    test('uses the server stamp, not the device clock', () async {
      // A phone running fast would otherwise skip every change in the window
      // between the two clocks.
      final serverTime = testEpoch.subtract(const Duration(minutes: 10));
      clock.now = testEpoch.add(const Duration(hours: 2));

      await database.syncDao.markSynchronized(
        scope,
        syncedAt: serverTime,
        now: clock(),
      );

      expect(await database.syncDao.cursorFor(scope), serverTime);
    });

    test('survives a failure untouched', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 3));

      await database.syncDao.markSynchronized(
        scope,
        syncedAt: serverTime,
        now: clock(),
      );
      await database.syncDao.markFailed(
        scope,
        now: clock(),
        error: 'SocketFailure',
      );

      // Advancing past a window the server never confirmed is how a client
      // silently skips a day of messages.
      expect(await database.syncDao.cursorFor(scope), serverTime);
      expect(
        (await database.syncDao.stateOf(scope))!.status,
        SyncStatus.failed,
      );
    });

    test('survives being marked stale untouched', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 3));

      await database.syncDao.markSynchronized(
        scope,
        syncedAt: serverTime,
        now: clock(),
      );
      await database.syncDao.markStale(scope);

      expect(await database.syncDao.cursorFor(scope), serverTime);
      expect((await database.syncDao.stateOf(scope))!.status, SyncStatus.stale);
    });

    test('survives entering the syncing phase untouched', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 3));

      await database.syncDao.markSynchronized(
        scope,
        syncedAt: serverTime,
        now: clock(),
      );
      await database.syncDao.markSyncing(scope, now: clock());

      expect(await database.syncDao.cursorFor(scope), serverTime);
    });
  });

  group('scope isolation', () {
    test('tracks each scope separately', () async {
      await database.syncDao.markSynchronized(
        'conversations',
        syncedAt: testEpoch,
        now: clock(),
      );
      await database.syncDao.markFailed('messages:c1', now: clock());

      // A stale thread must not make the whole app look stale.
      expect(
        (await database.syncDao.stateOf('conversations'))!.status,
        SyncStatus.synchronized,
      );
      expect(
        (await database.syncDao.stateOf('messages:c1'))!.status,
        SyncStatus.failed,
      );
    });
  });

  group('event deduplication', () {
    test('reports the first registration as new', () async {
      final isNew = await database.syncDao.registerEvent(
        eventId: 'e1',
        eventName: 'message.created',
        now: clock(),
      );

      expect(isNew, isTrue);
    });

    test('reports a repeat as already seen', () async {
      await database.syncDao.registerEvent(
        eventId: 'e1',
        eventName: 'message.created',
        now: clock(),
      );

      final isNew = await database.syncDao.registerEvent(
        eventId: 'e1',
        eventName: 'message.created',
        now: clock(),
      );

      // Regression guard: `insert` returns a stale rowid on an ignored insert,
      // which reported every duplicate as new and disabled deduplication
      // entirely. `insertReturningOrNull` is unambiguous.
      expect(isNew, isFalse);
    });

    test('hasProcessed reflects what was registered', () async {
      await database.syncDao.registerEvent(
        eventId: 'e1',
        eventName: 'x',
        now: clock(),
      );

      expect(await database.syncDao.hasProcessed('e1'), isTrue);
      expect(await database.syncDao.hasProcessed('e2'), isFalse);
    });

    test('prunes records older than the cutoff, keeping recent ones', () async {
      await database.syncDao.registerEvent(
        eventId: 'old',
        eventName: 'x',
        now: clock(),
      );

      clock.advance(const Duration(days: 2));

      await database.syncDao.registerEvent(
        eventId: 'recent',
        eventName: 'x',
        now: clock(),
      );

      final removed = await database.syncDao.pruneProcessedEvents(
        before: testEpoch.add(const Duration(days: 1)),
      );

      // Bounded on purpose: the window only has to outlast a reconnect.
      expect(removed, 1);
      expect(await database.syncDao.hasProcessed('old'), isFalse);
      expect(await database.syncDao.hasProcessed('recent'), isTrue);
    });
  });

  group('page cursor', () {
    const customers = 'customers';

    test('is null for a scope that has never walked', () async {
      expect(await database.syncDao.pageCursorFor(customers), isNull);
    });

    test('is stored and read back as written', () async {
      await database.syncDao.savePageCursor(customers, '{"page":7}');

      expect(await database.syncDao.pageCursorFor(customers), '{"page":7}');
    });

    test('clears with null once there is nothing to resume', () async {
      await database.syncDao.savePageCursor(customers, '{"page":7}');
      await database.syncDao.savePageCursor(customers, null);

      expect(await database.syncDao.pageCursorFor(customers), isNull);
    });

    test('leaves the rest of the scope as it was', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 3));
      await database.syncDao.markSynchronized(
        customers,
        syncedAt: serverTime,
        now: clock(),
      );

      await database.syncDao.savePageCursor(customers, '{"page":2}');

      final state = await database.syncDao.stateOf(customers);
      expect(state?.status, SyncStatus.synchronized);
      expect(state?.syncedAt, serverTime);
    });

    test('survives every status change', () async {
      // A walk interrupted by a failure, going offline or a new attempt must
      // pick up where it stopped rather than start again.
      await database.syncDao.savePageCursor(customers, '{"page":4}');

      await database.syncDao.markSyncing(customers, now: clock());
      expect(await database.syncDao.pageCursorFor(customers), '{"page":4}');

      await database.syncDao.markFailed(customers, now: clock(), error: 'x');
      expect(await database.syncDao.pageCursorFor(customers), '{"page":4}');

      await database.syncDao.markStale(customers);
      expect(await database.syncDao.pageCursorFor(customers), '{"page":4}');

      await database.syncDao.markSynchronized(
        customers,
        syncedAt: testEpoch,
        now: clock(),
      );
      expect(await database.syncDao.pageCursorFor(customers), '{"page":4}');
    });
  });

  group('watchState', () {
    test('re-emits as the phase changes', () async {
      final phases = <SyncStatus?>[];

      final subscription = database.syncDao
          .watchState(scope)
          .listen((row) => phases.add(row?.status));

      await pumpEventQueue();
      await database.syncDao.markSyncing(scope, now: clock());
      await pumpEventQueue();
      await database.syncDao.markSynchronized(
        scope,
        syncedAt: testEpoch,
        now: clock(),
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        phases,
        containsAllInOrder(<SyncStatus?>[
          null,
          SyncStatus.syncing,
          SyncStatus.synchronized,
        ]),
      );
    });
  });
}
