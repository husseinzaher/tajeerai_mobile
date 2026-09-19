import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/conversations/application/coordinators/outbox_coordinator.dart';
import 'package:tajeerai_mobile/features/conversations/data/repositories/conversation_repository_impl.dart';
import 'package:tajeerai_mobile/features/conversations/data/repositories/message_repository_impl.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';
import 'package:tajeerai_mobile/features/conversations/domain/services/conversation_service.dart';
import 'package:tajeerai_mobile/features/conversations/domain/services/message_service.dart';
import 'package:tajeerai_mobile/features/conversations/realtime/conversation_events.dart';
import 'package:tajeerai_mobile/features/conversations/realtime/conversation_socket_handler.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/database/tables/outbox_table.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/socket_event.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';
import 'application/fakes/fake_conversation_remote.dart';

/// End-to-end offline-first behaviour.
///
/// Unlike the unit tests, this wires the *real* repositories, DAOs, services,
/// outbox and socket handler against one in-memory database, faking only the
/// socket. It is the test that would catch a break in the seam between two
/// correct-in-isolation pieces -- which is where offline bugs actually live.
void main() {
  late AppDatabase database;
  late FakeConversationRemote remote;
  late ConversationRepositoryImpl conversations;
  late MessageRepositoryImpl messages;
  late ConversationService conversationService;
  late MessageService messageService;
  late OutboxCoordinator outbox;
  late ConversationSocketHandler handler;
  late FixedClock clock;

  var idCounter = 0;

  setUp(() async {
    database = openTestDatabase();
    remote = FakeConversationRemote();
    clock = FixedClock(testEpoch);
    idCounter = 0;

    final logger = Logger('test', verbose: false);

    conversations = ConversationRepositoryImpl(
      dao: database.conversationDao,
      remote: remote,
      logger: logger,
    );

    messages = MessageRepositoryImpl(
      dao: database.conversationDao,
      outbox: database.outboxDao,
      remote: remote,
      logger: logger,
      clock: clock.call,
    );

    conversationService = ConversationService(conversations);

    messageService = MessageService(
      repository: messages,
      conversationService: conversationService,
      idGenerator: () => 'client-${++idCounter}',
    );

    outbox = OutboxCoordinator(
      database: database,
      outbox: database.outboxDao,
      messages: messages,
      remote: remote,
      logger: logger,
      clock: clock.call,
      random: SeededRandom(),
    );

    handler = ConversationSocketHandler(
      conversations: conversations,
      messages: messages,
      syncDao: database.syncDao,
      logger: logger,
      clock: clock.call,
    );

    // A thread to work in.
    await conversations.upsertAll(<Conversation>[
      Conversation(
        id: 'c1',
        state: ConversationState.open,
        customerName: 'Ada',
        createdAt: testEpoch,
      ),
    ]);
  });

  tearDown(() async {
    await handler.dispose();
    await outbox.dispose();
    await database.close();
  });

  Future<Conversation?> thread() => conversations.findConversation('c1');

  Future<List<Message>> threadMessages() =>
      messageService.watchThread('c1').first;

  group('reading while offline', () {
    test('serves conversations from local storage with no socket', () async {
      final rail = await conversationService.watchInbox().first;

      expect(rail, hasLength(1));
      expect(rail.single.displayName, 'Ada');

      // Nothing was asked of the server to render the rail.
      expect(remote.listCalls, 0);
      expect(remote.syncCalls, 0);
    });

    test('serves a thread from local storage', () async {
      await messages.upsertAll(<Message>[
        Message(
          id: 'm1',
          conversationId: 'c1',
          direction: MessageDirection.inbound,
          state: MessageState.delivered,
          body: 'cached message',
          createdAt: testEpoch,
        ),
      ]);

      final thread = await threadMessages();

      expect(thread.single.body, 'cached message');
    });
  });

  group('writing while offline', () {
    test('a message is durable before it is sent', () async {
      // The socket is down.
      remote.failureToThrow = const SocketFailure(
        message: 'Not connected.',
        code: 'DISCONNECTED',
      );

      final composed = await messageService.compose(
        conversation: await thread(),
        rawBody: 'sent from a tunnel',
      );

      expect(composed.state, MessageState.pending);

      // Persisted, and queued, in one transaction: the app can be killed here
      // and the message still sends.
      final stored = await threadMessages();

      expect(stored.single.body, 'sent from a tunnel');
      expect(stored.single.state, MessageState.pending);
      expect(await database.outboxDao.find('client-1'), isNotNull);
    });

    test('the rail reorders immediately, before the server knows', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Offline.',
        code: 'DISCONNECTED',
      );

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'hello',
      );

      final conversation = await thread();

      expect(conversation!.lastMessagePreview, 'hello');
      expect(conversation.lastMessageAt, isNotNull);
    });

    test('draining while offline leaves the message queued', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Offline.',
        code: 'DISCONNECTED',
      );

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'hello',
      );

      await outbox.drain();

      final stored = await threadMessages();

      expect(stored.single.state, MessageState.pending);
      expect(
        (await database.outboxDao.find('client-1'))!.status,
        OutboxStatus.pending,
      );
    });
  });

  group('reconnecting', () {
    test('sends what was queued and re-keys it to the server id', () async {
      remote.failureToThrow = const SocketFailure(
        message: 'Offline.',
        code: 'DISCONNECTED',
      );

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'queued offline',
      );

      await outbox.drain();

      // The connection returns.
      remote
        ..failureToThrow = null
        ..nextMessageId = 'server-1';
      clock.advance(const Duration(minutes: 5));

      final sent = await outbox.drain();

      expect(sent, 1);

      final stored = await threadMessages();

      // One message, re-keyed in place -- not the optimistic bubble plus an
      // acknowledged twin.
      expect(stored, hasLength(1));
      expect(stored.single.id, 'server-1');
      expect(stored.single.state, MessageState.sent);
      expect(stored.single.body, 'queued offline');
    });

    test('a server broadcast for the same message does not duplicate it', () async {
      remote.nextMessageId = 'server-1';

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'hello',
      );
      await outbox.drain();

      // The server now broadcasts the message it accepted.
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'eventId': 'e1',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'server-1',
              'conversationId': 'c1',
              'direction': 'outbound',
              'state': 'delivered',
              'body': 'hello',
              'clientMessageId': 'client-1',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      final stored = await threadMessages();

      // The re-key means the broadcast lands on the row that is already there.
      expect(stored, hasLength(1));
      expect(stored.single.state, MessageState.delivered);
    });

    test(
      'a stale queued broadcast does not undo a sent acknowledgement',
      () async {
        remote.nextMessageId = 'server-1';

        await messageService.compose(
          conversation: await thread(),
          rawBody: 'hello',
        );
        await outbox.drain();

        expect((await threadMessages()).single.state, MessageState.sent);

        await handler.handle(
          SocketEvent.fromWire(
            ConversationRealtimeEvents.messageCreated,
            <String, Object?>{
              'eventId': 'e-queued',
              'occurredAt': testEpoch.add(const Duration(seconds: 1)).toIso8601String(),
              'conversationId': 'c1',
              'message': <String, Object?>{
                'id': 'server-1',
                'conversationId': 'c1',
                'direction': 'outbound',
                'state': 'queued',
                'body': 'hello',
                'clientMessageId': 'client-1',
                'createdAt': testEpoch.toIso8601String(),
              },
            },
          ),
        );

        final stored = await threadMessages();

        expect(stored, hasLength(1));
        expect(stored.single.state, MessageState.sent);
      },
    );

    test(
      'a broadcast that arrives before the acknowledgement does not duplicate',
      () async {
        remote.nextMessageId = 'server-1';

        await messageService.compose(
          conversation: await thread(),
          rawBody: 'hello',
        );

        await handler.handle(
          SocketEvent.fromWire(
            ConversationRealtimeEvents.messageCreated,
            <String, Object?>{
              'eventId': 'e-early',
              'occurredAt': testEpoch.toIso8601String(),
              'conversationId': 'c1',
              'message': <String, Object?>{
                'id': 'server-1',
                'conversationId': 'c1',
                'direction': 'outbound',
                'state': 'queued',
                'body': 'hello',
                'clientMessageId': 'client-1',
                'createdAt': testEpoch.toIso8601String(),
              },
            },
          ),
        );

        await outbox.drain();

        final stored = await threadMessages();

        expect(stored, hasLength(1));
        expect(stored.single.id, 'server-1');
        expect(stored.single.state, MessageState.sent);
      },
    );
  });

  group('realtime into local state', () {
    test('an incoming message reaches the thread and the rail', () async {
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'eventId': 'e1',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'm-in',
              'conversationId': 'c1',
              'direction': 'inbound',
              'state': 'delivered',
              'body': 'a customer reply',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      expect((await threadMessages()).single.body, 'a customer reply');
      expect((await thread())!.lastMessagePreview, 'a customer reply');
    });

    test('a replayed frame changes nothing', () async {
      final frame = SocketEvent.fromWire(
        ConversationRealtimeEvents.messageCreated,
        <String, Object?>{
          'eventId': 'replayed',
          'occurredAt': testEpoch.toIso8601String(),
          'conversationId': 'c1',
          'message': <String, Object?>{
            'id': 'm-in',
            'conversationId': 'c1',
            'direction': 'inbound',
            'state': 'delivered',
            'body': 'once only',
            'createdAt': testEpoch.toIso8601String(),
          },
        },
      );

      await handler.handle(frame);
      await handler.handle(frame);

      expect(await threadMessages(), hasLength(1));
    });

    test('a late status frame cannot undo newer state', () async {
      final newer = testEpoch.add(const Duration(minutes: 10));

      // The message is read, as of the newer stamp.
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageUpdated,
          <String, Object?>{
            'eventId': 'e-new',
            'occurredAt': newer.toIso8601String(),
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'm1',
              'conversationId': 'c1',
              'direction': 'outbound',
              'state': 'read',
              'body': 'hi',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      // An older "delivered" frame arrives afterwards.
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageUpdated,
          <String, Object?>{
            'eventId': 'e-old',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'm1',
              'conversationId': 'c1',
              'direction': 'outbound',
              'state': 'delivered',
              'body': 'hi',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      expect((await threadMessages()).single.state, MessageState.read);
    });
  });

  group('unread and read state', () {
    test('a server unread count reaches the rail', () async {
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.unreadUpdated,
          <String, Object?>{
            'eventId': 'e-unread',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'unreadCount': 4,
          },
        ),
      );

      expect((await thread())!.unreadCount, 4);
    });

    test(
      'opening a thread clears unread locally even with no connection',
      () async {
        await conversations.upsertAll(<Conversation>[
          Conversation(
            id: 'c1',
            state: ConversationState.open,
            unreadCount: 5,
            createdAt: testEpoch,
          ),
        ]);

        remote.failureToThrow = const SocketFailure(
          message: 'Offline.',
          code: 'DISCONNECTED',
        );

        await conversationService.markRead((await thread())!);

        // The badge clears the instant the thread opens; the next sync
        // reconciles with the server, which is authoritative.
        expect((await thread())!.unreadCount, 0);
      },
    );
  });

  group('the archived rule end to end', () {
    test('an archived thread refuses a message and queues nothing', () async {
      await conversations.upsertAll(<Conversation>[
        Conversation(
          id: 'c1',
          state: ConversationState.archived,
          isArchived: true,
          createdAt: testEpoch,
        ),
      ]);

      await expectLater(
        messageService.compose(
          conversation: await thread(),
          rawBody: 'should not send',
        ),
        throwsA(isA<ConflictFailure>()),
      );

      expect(await threadMessages(), isEmpty);
      expect(await database.outboxDao.due(now: clock()), isEmpty);
    });
  });

  group('failure and manual retry', () {
    test('a permanently rejected message is visible and retryable', () async {
      remote.failureToThrow = const ValidationFailure(message: 'Too long.');

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'rejected',
      );

      await outbox.drain();

      var stored = await threadMessages();

      expect(stored.single.state, MessageState.failed);

      // The user retries by hand once the problem is fixed.
      remote.failureToThrow = null;
      remote.nextMessageId = 'server-2';

      await outbox.retry('client-1');

      stored = await threadMessages();

      expect(stored.single.state, MessageState.sent);
      expect(stored.single.id, 'server-2');
    });

    test('discarding removes the message and its queued command', () async {
      remote.failureToThrow = const ValidationFailure(message: 'Nope.');

      await messageService.compose(
        conversation: await thread(),
        rawBody: 'to be discarded',
      );
      await outbox.drain();

      await outbox.discard('client-1');

      expect(await threadMessages(), isEmpty);
      expect(await database.outboxDao.find('client-1'), isNull);
    });
  });

  group('reactive delivery to the UI', () {
    test('the thread stream re-emits when a socket event lands', () async {
      final emissions = <int>[];

      final subscription = messageService
          .watchThread('c1')
          .listen((messages) => emissions.add(messages.length));

      await pumpEventQueue();

      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'eventId': 'e1',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'm-in',
              'conversationId': 'c1',
              'direction': 'inbound',
              'state': 'delivered',
              'body': 'live',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      await pumpEventQueue();
      await subscription.cancel();

      // This is the whole architecture in one assertion: a socket frame became
      // a database write became a UI update, with no widget touching a socket.
      expect(emissions, containsAllInOrder(<int>[0, 1]));
    });
  });
}
