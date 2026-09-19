import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/conversations/application/coordinators/outbox_coordinator.dart';
import 'package:tajeerai_mobile/features/conversations/application/events/conversation_app_events.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';
import 'package:tajeerai_mobile/features/conversations/realtime/conversation_events.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/database/tables/outbox_table.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import '../domain/fakes/fake_message_repository.dart';
import 'fakes/fake_conversation_media_remote.dart';
import 'fakes/fake_conversation_remote.dart';

void main() {
  late AppDatabase database;
  late FakeConversationRemote remote;
  late FakeConversationMediaRemote media;
  late FakeMessageRepository messages;
  late OutboxCoordinator coordinator;
  late FixedClock clock;

  setUp(() {
    database = openTestDatabase();
    remote = FakeConversationRemote();
    media = FakeConversationMediaRemote();
    messages = FakeMessageRepository();
    clock = FixedClock(testEpoch);

    coordinator = OutboxCoordinator(
      database: database,
      outbox: database.outboxDao,
      messages: messages,
      remote: remote,
      media: media,
      logger: Logger('test', verbose: false),
      clock: clock.call,
      // A seeded generator makes the jittered backoff deterministic, so the
      // retry tests assert on real behaviour rather than sleeping.
      random: SeededRandom(),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await database.close();
  });

  Future<void> queueSend({String id = 'client-1'}) {
    return database.outboxDao.enqueue(
      id: id,
      command: ConversationCommands.messageSend,
      payload: '{"conversationId":"c1","body":"hi","clientMessageId":"$id"}',
      scopeId: 'c1',
      now: clock(),
    );
  }

  group('successful acknowledgement', () {
    test('sends a queued message and settles the entry', () async {
      await queueSend();

      final sent = await coordinator.drain();

      expect(sent, 1);
      expect(remote.sentMessages, hasLength(1));
      expect(remote.sentMessages.single.clientMessageId, 'client-1');
      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.acknowledged,
      );
    });

    test(
      'moves the message to sending, then reconciles it to the server id',
      () async {
        remote.nextMessageId = 'server-99';
        await queueSend();

        await coordinator.drain();

        expect(messages.stateUpdates.first.state, MessageState.sending);
        expect(messages.reconciliations.single.serverMessageId, 'server-99');
        expect(messages.reconciliations.single.state, MessageState.sent);
      },
    );

    test('treats a deduplicated acknowledgement as a success', () async {
      // `deduplicated: true` means an earlier attempt already landed. That is
      // the idempotency key working, not an error -- re-sending would give the
      // customer a second copy.
      remote.nextDeduplicated = true;
      await queueSend();

      final sent = await coordinator.drain();

      expect(sent, 1);
      expect(messages.reconciliations, hasLength(1));
    });

    test('announces the send so the app can react', () async {
      final events = <ConversationAppEvent>[];
      final subscription = coordinator.events.listen(events.add);

      await queueSend();
      await coordinator.drain();
      await pumpEventQueue();
      await subscription.cancel();

      expect(events.whereType<ConversationMessageArrived>(), hasLength(1));
    });

    test('uploads media before sending the socket command', () async {
      final File file = File(
        '${Directory.systemTemp.path}/outbox-media-${clock().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(<int>[1, 2, 3]);

      await database.outboxDao.enqueue(
        id: 'client-media',
        command: ConversationCommands.messageSend,
        payload: jsonEncode(<String, Object?>{
          'conversationId': 'c1',
          'clientMessageId': 'client-media',
          'type': 'image',
          'localPath': file.path,
          'filename': 'photo.jpg',
          'mimeType': 'image/jpeg',
        }),
        scopeId: 'c1',
        now: clock(),
      );

      await coordinator.drain();

      expect(media.uploadCalls, 1);
      expect(remote.lastMediaId, 'media-1');
      expect(remote.lastSendType, 'image');
    });
  });

  group('offline and retryable failures', () {
    test('requeues with a backoff instead of failing', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Not connected.',
        code: 'DISCONNECTED',
      );

      await queueSend();
      await coordinator.drain();

      final entry = await database.outboxDao.find('client-1');

      // Still going to be sent -- showing a failure the app is about to retry
      // teaches the user to distrust the indicator.
      expect(entry!.status, OutboxStatus.pending);
      expect(entry.attempts, 1);
      expect(entry.nextAttemptAt!.isAfter(clock()), isTrue);
      expect(messages.stateUpdates.last.state, MessageState.pending);
    });

    test('is not due again until the backoff elapses', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Timed out.',
        code: 'TIMEOUT',
      );

      await queueSend();
      await coordinator.drain();

      final attemptsBefore = remote.sendAttempts;
      await coordinator.drain();

      expect(remote.sendAttempts, attemptsBefore);
    });

    test('succeeds on a later attempt once the connection returns', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Offline.',
        code: 'DISCONNECTED',
      );

      await queueSend();
      await coordinator.drain();

      // The connection comes back.
      remote.failureToThrow = null;
      clock.advance(const Duration(minutes: 5));

      final sent = await coordinator.drain();

      expect(sent, 1);
      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.acknowledged,
      );
    });

    test('reuses the original idempotency key on every attempt', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Offline.',
        code: 'DISCONNECTED',
      );

      await queueSend();
      await coordinator.drain();

      remote.failureToThrow = null;
      clock.advance(const Duration(minutes: 5));
      await coordinator.drain();

      // A fresh key on retry is how a resend becomes a duplicate message for
      // the customer.
      expect(remote.attemptedClientMessageIds.toSet(), <String>{'client-1'});
    });

    test('gives up after the attempt cap and surfaces the failure', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Timed out.',
        code: 'TIMEOUT',
      );

      await queueSend();

      for (
        var attempt = 0;
        attempt < OutboxCoordinator.maxAttempts;
        attempt++
      ) {
        clock.advance(const Duration(minutes: 10));
        await coordinator.drain();
      }

      final entry = await database.outboxDao.find('client-1');

      expect(entry!.status, OutboxStatus.failed);
      expect(messages.stateUpdates.last.state, MessageState.failed);
    });
  });

  group('permanent rejections', () {
    test(
      'a validation rejection fails immediately, without retrying',
      () async {
        remote.failureToThrow = const ValidationFailure(message: 'Bad body.');

        await queueSend();
        await coordinator.drain();

        final entry = await database.outboxDao.find('client-1');

        // The server will reject the identical command again; retrying would
        // burn the user's battery to reach the same answer.
        expect(entry!.status, OutboxStatus.failed);
        expect(entry.attempts, 1);
      },
    );

    test('a conflict fails immediately', () async {
      remote.failureToThrow = const ConflictFailure(message: 'Archived.');

      await queueSend();
      await coordinator.drain();

      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.failed,
      );
    });

    test('an authorization rejection fails immediately', () async {
      remote.failureToThrow = const AuthorizationFailure(message: 'Nope.');

      await queueSend();
      await coordinator.drain();

      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.failed,
      );
    });

    test('an expired session is retried, not failed', () async {
      // The socket layer refreshes the session and reconnects; this entry
      // should go out once it does.
      remote.failureToThrow = const AuthenticationFailure(
        message: 'Session expired.',
        sessionExpired: true,
      );

      await queueSend();
      await coordinator.drain();

      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.pending,
      );
    });

    test('announces a permanent failure', () async {
      final events = <ConversationAppEvent>[];
      final subscription = coordinator.events.listen(events.add);

      remote.failureToThrow = const ValidationFailure(message: 'Bad.');
      await queueSend();
      await coordinator.drain();
      await pumpEventQueue();
      await subscription.cancel();

      expect(events.whereType<ConversationMutationFailed>(), hasLength(1));
    });

    test(
      'an unsupported command fails rather than sitting in the queue',
      () async {
        await database.outboxDao.enqueue(
          id: 'weird',
          command: 'nonexistent:command',
          payload: '{}',
          now: clock(),
        );

        await coordinator.drain();

        // A silent skip would leave the entry queued forever, invisible.
        expect(
          (await database.outboxDao.find('weird'))!.status,
          OutboxStatus.failed,
        );
      },
    );
  });

  group('manual retry and discard', () {
    test('retry requeues a failed entry and sends it', () async {
      remote.failureToThrow = const ValidationFailure(message: 'Bad.');
      await queueSend();
      await coordinator.drain();

      remote.failureToThrow = null;
      await coordinator.retry('client-1');

      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.acknowledged,
      );
    });

    test('retry of an unknown entry reports it clearly', () async {
      await expectLater(
        coordinator.retry('never-existed'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('discard removes the entry and its optimistic message', () async {
      await queueSend();

      await coordinator.discard('client-1');

      expect(await database.outboxDao.find('client-1'), isNull);
      expect(messages.removed, <String>['client-1']);
    });

    test('discarding an unknown entry is a no-op', () async {
      await coordinator.discard('never-existed');

      expect(messages.removed, isEmpty);
    });
  });

  group('crash recovery', () {
    test('recovers entries left in flight by a killed process', () async {
      await queueSend();
      await database.outboxDao.claim('client-1', now: clock());

      final recovered = await coordinator.recoverInterrupted();

      expect(recovered, 1);
      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.pending,
      );
    });

    test('also returns the message from sending to pending', () async {
      // Regression, seen on a real device: `_sendMessage` moves the row to
      // `sending` before dispatching, so a process killed mid-flight left the
      // bubble reading "Sending" forever while the queue had quietly gone back
      // to `pending`. The two must be recovered together.
      await queueSend();
      await database.outboxDao.claim('client-1', now: clock());
      await messages.updateState(
        messageId: 'client-1',
        state: MessageState.sending,
      );

      await coordinator.recoverInterrupted();

      expect(messages.stateUpdates.last.messageId, 'client-1');
      expect(messages.stateUpdates.last.state, MessageState.pending);
    });

    test('leaves a pending entry\'s message alone', () async {
      await queueSend();

      await coordinator.recoverInterrupted();

      // Nothing was in flight, so nothing needed resetting.
      expect(messages.stateUpdates, isEmpty);
    });
  });

  group('concurrency', () {
    test('two concurrent drains do not send the same entry twice', () async {
      await queueSend();

      await Future.wait(<Future<int>>[
        coordinator.drain(),
        coordinator.drain(),
      ]);

      // The re-entry guard plus the atomic claim: a message must reach the
      // customer once.
      expect(remote.sendAttempts, 1);
    });
  });

  group('summary', () {
    test('counts pending and failed work separately', () async {
      await queueSend(id: 'a');
      await queueSend(id: 'b');

      remote.failureToThrow = const ValidationFailure(message: 'Bad.');
      await coordinator.drain();

      final summary = await coordinator.watchSummary().first;

      expect(summary.failed, 2);
      expect(summary.pending, 0);
      expect(summary.isEmpty, isFalse);
    });

    test('is empty when nothing is queued', () async {
      final summary = await coordinator.watchSummary().first;

      expect(summary.isEmpty, isTrue);
    });
  });

  group('pruning', () {
    test('drops acknowledged entries older than a day', () async {
      await queueSend();
      await coordinator.drain();

      clock.advance(const Duration(days: 2));

      expect(await coordinator.prune(), 1);
    });
  });
}
