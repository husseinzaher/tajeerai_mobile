import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/realtime/conversation_events.dart';
import 'package:TajeerAi/features/conversations/realtime/conversation_socket_handler.dart';
import 'package:TajeerAi/features/conversations/realtime/message_events.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_event.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import '../domain/fakes/fake_conversation_repository.dart';
import '../domain/fakes/fake_message_repository.dart';

/// A `message.created` frame in the backend's documented shape.
SocketEvent _messageEvent({
  String eventId = 'e1',
  DateTime? occurredAt,
  String messageId = 'm1',
  String conversationId = 'c1',
  String body = 'hello',
}) {
  return SocketEvent.fromWire(
    ConversationRealtimeEvents.messageCreated,
    <String, Object?>{
      'eventId': eventId,
      'occurredAt': (occurredAt ?? testEpoch).toIso8601String(),
      'conversationId': conversationId,
      'message': <String, Object?>{
        'id': messageId,
        'conversationId': conversationId,
        'direction': 'inbound',
        'type': 'text',
        'state': 'delivered',
        'body': body,
        'createdAt': (occurredAt ?? testEpoch).toIso8601String(),
        'isFromBot': false,
      },
    },
  );
}

SocketEvent _conversationEvent({
  String eventId = 'e2',
  DateTime? occurredAt,
  String conversationId = 'c1',
  String state = 'open',
  int unreadCount = 0,
}) {
  return SocketEvent.fromWire(
    ConversationRealtimeEvents.conversationUpdated,
    <String, Object?>{
      'eventId': eventId,
      'occurredAt': (occurredAt ?? testEpoch).toIso8601String(),
      'conversation': <String, Object?>{
        'id': conversationId,
        'state': state,
        'unreadCount': unreadCount,
        'createdAt': testEpoch.toIso8601String(),
        'tags': <Object?>[],
      },
    },
  );
}

void main() {
  late AppDatabase database;
  late FakeConversationRepository conversations;
  late FakeMessageRepository messages;
  late ConversationSocketHandler handler;
  late FixedClock clock;

  setUp(() {
    database = openTestDatabase();
    conversations = FakeConversationRepository();
    messages = FakeMessageRepository();
    clock = FixedClock(testEpoch);

    handler = ConversationSocketHandler(
      conversations: conversations,
      messages: messages,
      // A real SyncDao against a real database: deduplication is an
      // insert-or-ignore race, and a fake would not exercise it.
      syncDao: database.syncDao,
      logger: Logger('test', verbose: false),
      clock: clock.call,
    );
  });

  tearDown(() async {
    await handler.dispose();
    await database.close();
  });

  group('valid events', () {
    test('persists an incoming message', () async {
      final applied = await handler.handle(_messageEvent());

      expect(applied, isTrue);
      expect(messages.upserted, hasLength(1));
      expect(messages.upserted.single.id, 'm1');
      expect(messages.upserted.single.body, 'hello');
    });

    test('persists a conversation update', () async {
      final applied = await handler.handle(_conversationEvent());

      expect(applied, isTrue);
      expect(conversations.upserted.single.id, 'c1');
    });

    test('applies an unread count from the server verbatim', () async {
      conversations.seed(<Conversation>[
        Conversation(
          id: 'c1',
          state: ConversationState.open,
          unreadCount: 1,
          createdAt: testEpoch,
        ),
      ]);

      final applied = await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.unreadUpdated,
          <String, Object?>{
            'eventId': 'e-unread',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'unreadCount': 7,
          },
        ),
      );

      expect(applied, isTrue);

      // Taken from the event, never incremented locally: another agent reading
      // the thread elsewhere changes this number, and a self-counting client
      // drifts within minutes.
      expect(conversations.upserted.last.unreadCount, 7);
    });

    test('removes a message the provider never accepted', () async {
      final applied = await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageRemoved,
          <String, Object?>{
            'eventId': 'e-removed',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'messageId': 'm1',
          },
        ),
      );

      expect(applied, isTrue);
      expect(messages.removed, <String>['m1']);
    });
  });

  group('duplicate events', () {
    test('applies a frame once and skips the replay', () async {
      final first = await handler.handle(_messageEvent(eventId: 'same'));
      final second = await handler.handle(_messageEvent(eventId: 'same'));

      expect(first, isTrue);

      // A reconnect replays facts the client already holds. Applying one twice
      // is how an unread count double-counts.
      expect(second, isFalse);
      expect(messages.upserted, hasLength(1));
    });

    test('treats distinct event ids as distinct facts', () async {
      await handler.handle(_messageEvent(eventId: 'a', messageId: 'm1'));
      await handler.handle(_messageEvent(eventId: 'b', messageId: 'm2'));

      expect(messages.upserted, hasLength(2));
    });

    test('records the event id so a later replay is also skipped', () async {
      await handler.handle(_messageEvent(eventId: 'persisted'));

      expect(await database.syncDao.hasProcessed('persisted'), isTrue);
    });
  });

  group('event ordering', () {
    test('passes occurredAt down so a stale frame cannot overwrite', () async {
      final newer = testEpoch.add(const Duration(minutes: 5));

      await handler.handle(_messageEvent(eventId: 'e1', occurredAt: newer));

      // The handler's contract is to hand the stamp to the write; the DAO test
      // covers the write actually refusing to go backwards.
      expect(messages.upsertEventStamps.single, newer);
    });

    test('forwards no stamp for a frame without one', () async {
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'conversationId': 'c1',
            'message': <String, Object?>{
              'id': 'm-nostamp',
              'conversationId': 'c1',
              'direction': 'inbound',
              'state': 'delivered',
              'body': 'hi',
              'createdAt': testEpoch.toIso8601String(),
            },
          },
        ),
      );

      // Without an envelope there is nothing to order on; the write proceeds
      // unguarded rather than being dropped.
      expect(messages.upsertEventStamps.single, isNull);
    });
  });

  group('malformed and unknown events', () {
    test('drops a frame whose payload cannot be decoded', () async {
      final applied = await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'eventId': 'bad',
            'occurredAt': testEpoch.toIso8601String(),
            // No `message` key at all.
            'conversationId': 'c1',
          },
        ),
      );

      expect(applied, isFalse);
      expect(messages.upserted, isEmpty);
    });

    test(
      'drops a message with no id rather than writing a broken row',
      () async {
        final applied = await handler.handle(
          SocketEvent.fromWire(
            ConversationRealtimeEvents.messageCreated,
            <String, Object?>{
              'eventId': 'bad-id',
              'occurredAt': testEpoch.toIso8601String(),
              'conversationId': 'c1',
              'message': <String, Object?>{'body': 'no id here'},
            },
          ),
        );

        expect(applied, isFalse);
        expect(messages.upserted, isEmpty);
      },
    );

    test('keeps processing after a malformed frame', () async {
      await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.messageCreated,
          <String, Object?>{
            'eventId': 'bad',
            'occurredAt': testEpoch.toIso8601String(),
          },
        ),
      );

      // One bad frame must not take down the subscription.
      final applied = await handler.handle(_messageEvent(eventId: 'good'));

      expect(applied, isTrue);
      expect(messages.upserted, hasLength(1));
    });

    test('ignores an event this feature does not own', () async {
      final applied = await handler.handle(
        SocketEvent.fromWire('chatbot.state-changed', <String, Object?>{
          'eventId': 'other',
        }),
      );

      expect(applied, isFalse);
      expect(messages.upserted, isEmpty);

      // Not claimed either -- another feature's handler must still see it.
      expect(await database.syncDao.hasProcessed('other'), isFalse);
    });

    test('ignores an unread event for a thread it has never seen', () async {
      final applied = await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.unreadUpdated,
          <String, Object?>{
            'eventId': 'e-unknown',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'never-synced',
            'unreadCount': 3,
          },
        ),
      );

      // Not an error: the conversation simply has not synced yet, and the sync
      // will carry the current count with it.
      expect(applied, isFalse);
    });
  });

  group('message.media-ready', () {
    test('updates the stored media url', () async {
      messages.seed(<Message>[
        Message(
          id: 'm1',
          conversationId: 'c1',
          direction: MessageDirection.inbound,
          state: MessageState.delivered,
          type: 'image',
          createdAt: testEpoch,
        ),
      ]);

      final applied = await handler.handle(
        SocketEvent.fromWire(
          ConversationRealtimeEvents.mediaReady,
          <String, Object?>{
            'eventId': 'e-media',
            'occurredAt': testEpoch.toIso8601String(),
            'conversationId': 'c1',
            'messageId': 'm1',
            'mediaUrl': 'https://example.com/photo.jpg',
            'type': 'image',
          },
        ),
      );

      expect(applied, isTrue);
      expect(
        (await messages.findMessage('m1'))!.mediaUrl,
        'https://example.com/photo.jpg',
      );
    });
  });

  group('typing', () {
    test(
      'publishes typing as a transient event, never persisting it',
      () async {
        final received = <MessageRealtimeEvent>[];
        final subscription = handler.transientEvents.listen(received.add);

        await handler.handle(
          SocketEvent.fromWire(
            ConversationRealtimeEvents.typing,
            <String, Object?>{
              'conversationId': 'c1',
              'userId': 'u2',
              'isTyping': true,
            },
          ),
        );

        await pumpEventQueue();
        await subscription.cancel();

        expect(received, hasLength(1));
        expect(received.single, isA<TypingChanged>());
        expect((received.single as TypingChanged).isTyping, isTrue);

        // Persisting something that expires in seconds would be a write per
        // keystroke, per agent.
        expect(messages.upserted, isEmpty);
        expect(conversations.upserted, isEmpty);
      },
    );

    test('is exempt from deduplication', () async {
      final received = <MessageRealtimeEvent>[];
      final subscription = handler.transientEvents.listen(received.add);

      final frame = SocketEvent.fromWire(
        ConversationRealtimeEvents.typing,
        <String, Object?>{'conversationId': 'c1', 'isTyping': true},
      );

      await handler.handle(frame);
      await handler.handle(frame);

      await pumpEventQueue();
      await subscription.cancel();

      // Two identical frames a second apart both mean "still typing".
      expect(received, hasLength(2));
    });
  });

  group('attach', () {
    test('processes frames arriving on the transport stream', () async {
      final controller = Stream<SocketEvent>.fromIterable(<SocketEvent>[
        _messageEvent(eventId: 'streamed'),
      ]);

      handler.attach(controller);
      await pumpEventQueue();

      expect(messages.upserted, hasLength(1));
    });
  });
}
