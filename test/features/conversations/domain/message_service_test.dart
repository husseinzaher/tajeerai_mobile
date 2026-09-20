import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/domain/services/conversation_service.dart';
import 'package:TajeerAi/features/conversations/domain/services/message_service.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/message_content.dart';

import '../../../support/fixed_clock.dart';
import 'fakes/fake_conversation_repository.dart';
import 'fakes/fake_message_repository.dart';

Conversation _conversation({bool isArchived = false}) => Conversation(
  id: 'c1',
  state: isArchived ? ConversationState.archived : ConversationState.open,
  isArchived: isArchived,
  createdAt: testEpoch,
);

Message _message({
  String id = 'm1',
  MessageState state = MessageState.failed,
  String? clientMessageId = 'client-1',
  MessageDirection direction = MessageDirection.outbound,
}) {
  return Message(
    id: id,
    conversationId: 'c1',
    clientMessageId: clientMessageId,
    direction: direction,
    state: state,
    body: 'hello',
    createdAt: testEpoch,
  );
}

void main() {
  late FakeMessageRepository messages;
  late FakeConversationRepository conversations;
  late MessageService service;
  var idCounter = 0;

  setUp(() {
    idCounter = 0;
    messages = FakeMessageRepository();
    conversations = FakeConversationRepository();
    service = MessageService(
      repository: messages,
      conversationService: ConversationService(conversations),
      idGenerator: () => 'generated-${++idCounter}',
    );
  });

  group('compose', () {
    test('queues a valid message and returns it optimistically', () async {
      final message = await service.compose(
        conversation: _conversation(),
        rawBody: 'hello there',
        authorId: 'u1',
        authorName: 'Ada',
      );

      expect(message.state, MessageState.pending);
      expect(message.direction, MessageDirection.outbound);
      expect(message.body, 'hello there');
      expect(messages.enqueued, hasLength(1));
      expect(messages.enqueued.single.clientMessageId, 'generated-1');
    });

    test('refuses to send into an archived conversation', () async {
      await expectLater(
        service.compose(
          conversation: _conversation(isArchived: true),
          rawBody: 'hello',
        ),
        throwsA(
          isA<ConflictFailure>().having(
            (failure) => failure.message,
            'message',
            contains('archived'),
          ),
        ),
      );

      // Refused before anything is written -- no orphan row is left behind.
      expect(messages.enqueued, isEmpty);
    });

    test('refuses to send into an unknown conversation', () async {
      await expectLater(
        service.compose(conversation: null, rawBody: 'hello'),
        throwsA(isA<ConflictFailure>()),
      );

      expect(messages.enqueued, isEmpty);
    });

    test('rejects an empty message with a field error', () async {
      await expectLater(
        service.compose(conversation: _conversation(), rawBody: '   '),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.errorsFor('body'),
            'body errors',
            <String>['message.empty'],
          ),
        ),
      );

      expect(messages.enqueued, isEmpty);
    });

    test('rejects a message over the provider limit', () async {
      await expectLater(
        service.compose(
          conversation: _conversation(),
          rawBody: 'x' * (MessageContent.maxLength + 1),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.errorsFor('body'),
            'body errors',
            <String>['message.tooLong'],
          ),
        ),
      );
    });

    test('generates a fresh idempotency key per message', () async {
      await service.compose(conversation: _conversation(), rawBody: 'one');
      await service.compose(conversation: _conversation(), rawBody: 'two');

      expect(messages.enqueued.map((m) => m.clientMessageId), <String>[
        'generated-1',
        'generated-2',
      ]);
    });
  });

  group('thread ordering', () {
    test('sorts oldest first, which is reading order', () {
      final sorted = MessageService.sortForThread(<Message>[
        _message(id: 'b')
            .copyWith(id: 'b')
            .withCreatedAt(testEpoch.add(const Duration(minutes: 2))),
        _message(id: 'a').withCreatedAt(testEpoch),
      ]);

      expect(sorted.map((m) => m.id), <String>['a', 'b']);
    });

    test('breaks ties on id so the order is stable', () {
      // Two messages sharing a timestamp happens whenever a sync writes a page
      // at once. Without a tiebreak they would swap between rebuilds and make
      // the list jump under the reader.
      final first = MessageService.sortForThread(<Message>[
        _message(id: 'zzz').withCreatedAt(testEpoch),
        _message(id: 'aaa').withCreatedAt(testEpoch),
      ]);

      final second = MessageService.sortForThread(<Message>[
        _message(id: 'aaa').withCreatedAt(testEpoch),
        _message(id: 'zzz').withCreatedAt(testEpoch),
      ]);

      expect(first.map((m) => m.id), <String>['aaa', 'zzz']);
      expect(second.map((m) => m.id), first.map((m) => m.id));
    });

    test('handles an empty thread', () {
      expect(MessageService.sortForThread(<Message>[]), isEmpty);
    });
  });

  group('state transitions', () {
    test('delivery states only move forward', () {
      expect(
        MessageService.canTransition(MessageState.sent, MessageState.delivered),
        isTrue,
      );
      expect(
        MessageService.canTransition(MessageState.delivered, MessageState.read),
        isTrue,
      );

      // WhatsApp receipts arrive out of order often enough that without this a
      // read message flips back to delivered when the older receipt lands.
      expect(
        MessageService.canTransition(MessageState.read, MessageState.delivered),
        isFalse,
      );
      expect(
        MessageService.canTransition(MessageState.sent, MessageState.sending),
        isFalse,
      );
    });

    test('a move to failed is always allowed', () {
      // A failure is current news whatever came before it.
      expect(
        MessageService.canTransition(MessageState.sent, MessageState.failed),
        isTrue,
      );
      expect(
        MessageService.canTransition(MessageState.pending, MessageState.failed),
        isTrue,
      );
    });

    test('a repeat of the same state is not a transition', () {
      expect(
        MessageService.canTransition(MessageState.sent, MessageState.sent),
        isFalse,
      );
    });
  });

  group('retry', () {
    test('returns a failed message to pending, keeping its key', () async {
      final retried = await service.prepareRetry(_message());

      expect(retried.state, MessageState.pending);

      // Reusing the original key is what makes the retry idempotent; a fresh
      // one would give the customer a duplicate.
      expect(retried.clientMessageId, 'client-1');
      expect(messages.stateUpdates.single.state, MessageState.pending);
    });

    test('refuses to retry a message that is not failed', () async {
      await expectLater(
        service.prepareRetry(_message(state: MessageState.sent)),
        throwsA(isA<ConflictFailure>()),
      );

      expect(messages.stateUpdates, isEmpty);
    });
  });

  group('discard', () {
    test('removes a message the server never accepted', () async {
      await service.discard(_message(state: MessageState.failed));

      expect(messages.removed, <String>['m1']);
    });

    test('refuses to discard a message the customer already has', () async {
      await expectLater(
        service.discard(_message(state: MessageState.delivered)),
        throwsA(isA<ConflictFailure>()),
      );

      expect(messages.removed, isEmpty);
    });
  });
}

/// Rebuilds a message at a different time. `copyWith` deliberately does not
/// expose `createdAt` -- a message's own timestamp is not something the app
/// edits -- so the test constructs one instead.
extension on Message {
  Message withCreatedAt(DateTime createdAt) => Message(
    id: id,
    conversationId: conversationId,
    clientMessageId: clientMessageId,
    direction: direction,
    state: state,
    body: body,
    createdAt: createdAt,
  );
}
