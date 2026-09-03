import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/conversations/application/coordinators/conversation_sync_coordinator.dart';
import 'package:tajeerai_mobile/features/conversations/application/coordinators/outbox_coordinator.dart';
import 'package:tajeerai_mobile/features/conversations/application/events/conversation_app_events.dart';
import 'package:tajeerai_mobile/features/conversations/application/state/sync_state.dart';
import 'package:tajeerai_mobile/features/conversations/domain/repositories/conversation_repository.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/database/tables/sync_state_table.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/connection/connection_state.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import '../domain/fakes/fake_conversation_repository.dart';
import '../domain/fakes/fake_message_repository.dart';
import 'fakes/fake_conversation_remote.dart';

void main() {
  late AppDatabase database;
  late FakeConversationRepository conversations;
  late OutboxCoordinator outbox;
  late ConversationSyncCoordinator coordinator;
  late FixedClock clock;

  setUp(() {
    database = openTestDatabase();
    conversations = FakeConversationRepository();
    clock = FixedClock(testEpoch);

    outbox = OutboxCoordinator(
      database: database,
      outbox: database.outboxDao,
      messages: FakeMessageRepository(),
      remote: FakeConversationRemote(),
      logger: Logger('test', verbose: false),
      clock: clock.call,
      random: SeededRandom(),
    );

    coordinator = ConversationSyncCoordinator(
      conversations: conversations,
      syncDao: database.syncDao,
      outbox: outbox,
      logger: Logger('test', verbose: false),
      clock: clock.call,
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    await outbox.dispose();
    await database.close();
  });

  group('first synchronisation', () {
    test('pulls a page of the rail when there is no cursor', () async {
      final written = await coordinator.performInitialSync();

      expect(conversations.syncListCalls, 1);
      expect(written, 0);
      expect(coordinator.state.phase, SyncPhase.synchronized);
    });

    test('records a cursor so the next pass is incremental', () async {
      await coordinator.performInitialSync();

      expect(
        await database.syncDao.cursorFor(
          ConversationSyncCoordinator.inboxScope,
        ),
        isNotNull,
      );
    });

    test('synchronize picks the initial pass when no cursor exists', () async {
      await coordinator.synchronize();

      expect(conversations.syncListCalls, 1);
      expect(conversations.lastSyncSince, isNull);
    });
  });

  group('incremental synchronisation', () {
    test('asks for changes since the stored cursor', () async {
      await coordinator.performInitialSync();
      final cursor = await database.syncDao.cursorFor(
        ConversationSyncCoordinator.inboxScope,
      );

      await coordinator.synchronize();

      expect(conversations.lastSyncSince, cursor);
    });

    test('advances the cursor to the server stamp', () async {
      final serverTime = testEpoch.add(const Duration(hours: 3));

      conversations.nextSyncOutcome = SyncOutcome(
        conversationsWritten: 2,
        messagesWritten: 7,
        syncedAt: serverTime,
      );

      await coordinator.performIncrementalSync(testEpoch);

      expect(
        await database.syncDao.cursorFor(
          ConversationSyncCoordinator.inboxScope,
        ),
        serverTime,
      );
      expect(coordinator.state.syncedAt, serverTime);
    });

    test('announces what the pass achieved', () async {
      final events = <ConversationAppEvent>[];
      final subscription = coordinator.events.listen(events.add);

      conversations.nextSyncOutcome = SyncOutcome(
        conversationsWritten: 3,
        messagesWritten: 9,
        syncedAt: testEpoch,
      );

      await coordinator.performIncrementalSync(testEpoch);
      await pumpEventQueue();
      await subscription.cancel();

      final completed = events.whereType<ConversationSyncCompleted>().single;

      expect(completed.conversationsWritten, 3);
      expect(completed.messagesWritten, 9);
    });
  });

  group('failure handling', () {
    test('reports failure without advancing the cursor', () async {
      final serverTime = testEpoch.add(const Duration(hours: 1));

      conversations.nextSyncOutcome = SyncOutcome(
        conversationsWritten: 0,
        messagesWritten: 0,
        syncedAt: serverTime,
      );
      await coordinator.performIncrementalSync(testEpoch);

      conversations.failureToThrow = const SocketFailure(
        message: 'Connection lost.',
      );
      await coordinator.performIncrementalSync(serverTime);

      // The next attempt must re-request the same window; advancing past an
      // unconfirmed one silently skips whatever happened in it.
      expect(
        await database.syncDao.cursorFor(
          ConversationSyncCoordinator.inboxScope,
        ),
        serverTime,
      );
      expect(coordinator.state.phase, SyncPhase.failed);
    });

    test('leaves the data readable after a failure', () async {
      conversations.failureToThrow = const SocketFailure(
        message: 'Connection lost.',
      );

      await coordinator.performInitialSync();

      // Failure is about freshness, not about the screen being broken.
      expect(coordinator.state.phase, SyncPhase.failed);
      expect(coordinator.state.message, isNotNull);
    });

    test('records the failure against the scope', () async {
      conversations.failureToThrow = const SynchronizationFailure(
        message: 'Nope.',
      );

      await coordinator.performInitialSync();

      final state = await database.syncDao.stateOf(
        ConversationSyncCoordinator.inboxScope,
      );

      expect(state!.status, SyncStatus.failed);
      expect(state.lastError, isNotNull);
    });

    test('recovers on a later successful pass', () async {
      conversations.failureToThrow = const SocketFailure(message: 'Nope.');
      await coordinator.performInitialSync();

      conversations.failureToThrow = null;
      await coordinator.performInitialSync();

      expect(coordinator.state.phase, SyncPhase.synchronized);
      expect(coordinator.state.message, isNull);
    });
  });

  group('connection versus synchronisation', () {
    test('going offline marks the scope stale, not failed', () async {
      final states = StreamController<SocketConnectionState>.broadcast();
      final connections = StreamController<void>.broadcast();

      coordinator.bindTo(
        connections: connections.stream,
        connectionStates: states.stream,
      );

      states.add(SocketConnectionState.disconnected);
      await pumpEventQueue();

      // The data on screen is still valid; only its freshness is in question.
      expect(coordinator.state.phase, SyncPhase.stale);

      await states.close();
      await connections.close();
    });

    test('reconnecting triggers a catch-up and drains the outbox', () async {
      final states = StreamController<SocketConnectionState>.broadcast();
      final connections = StreamController<void>.broadcast();

      coordinator.bindTo(
        connections: connections.stream,
        connectionStates: states.stream,
      );

      connections.add(null);
      await pumpEventQueue();

      // A socket coming back does not make the client current -- events
      // delivered while it was closed are gone. This is what closes the gap.
      expect(conversations.syncListCalls, 1);

      await states.close();
      await connections.close();
    });

    test('binding twice does not double-subscribe', () async {
      final states = StreamController<SocketConnectionState>.broadcast();
      final connections = StreamController<void>.broadcast();

      coordinator
        ..bindTo(
          connections: connections.stream,
          connectionStates: states.stream,
        )
        ..bindTo(
          connections: connections.stream,
          connectionStates: states.stream,
        );

      connections.add(null);
      await pumpEventQueue();

      expect(conversations.syncListCalls, 1);

      await states.close();
      await connections.close();
    });
  });

  group('re-entry', () {
    test('a second pass while one is running is ignored', () async {
      final first = coordinator.performInitialSync();
      final second = coordinator.performInitialSync();

      await Future.wait(<Future<int>>[first, second]);

      expect(conversations.syncListCalls, 1);
    });
  });

  group('staleness', () {
    test('data with no sync is stale', () {
      const state = ConversationSyncState();

      expect(state.isStaleAt(testEpoch), isTrue);
    });

    test('data synced recently is fresh', () {
      final state = ConversationSyncState(
        phase: SyncPhase.synchronized,
        syncedAt: testEpoch,
      );

      expect(
        state.isStaleAt(testEpoch.add(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('data synced long ago is stale', () {
      final state = ConversationSyncState(
        phase: SyncPhase.synchronized,
        syncedAt: testEpoch,
      );

      expect(state.isStaleAt(testEpoch.add(const Duration(hours: 1))), isTrue);
    });

    test('a pass in flight is never reported stale', () {
      final state = ConversationSyncState(
        phase: SyncPhase.syncing,
        syncedAt: testEpoch,
      );

      expect(state.isStaleAt(testEpoch.add(const Duration(days: 1))), isFalse);
    });
  });
}
