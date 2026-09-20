import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/message_content.dart';

import '../../../support/fixed_clock.dart';

Conversation _conversation() => Conversation(
  id: 'c1',
  state: ConversationState.open,
  customerName: 'Ada',
  unreadCount: 2,
  createdAt: testEpoch,
);

Message _message({MessageState state = MessageState.sent}) => Message(
  id: 'm1',
  conversationId: 'c1',
  direction: MessageDirection.outbound,
  state: state,
  body: 'hello',
  createdAt: testEpoch,
);

void main() {
  group('Conversation', () {
    test('copyWith changes only what it is given', () {
      final updated = _conversation().copyWith(unreadCount: 0);

      expect(updated.unreadCount, 0);
      expect(updated.id, 'c1');
      expect(updated.customerName, 'Ada');
      expect(updated.state, ConversationState.open);
    });

    test('copyWith with nothing returns an equal conversation', () {
      expect(_conversation().copyWith(), _conversation());
    });

    test('copyWith can archive a thread', () {
      final archived = _conversation().copyWith(isArchived: true);

      expect(archived.acceptsNewMessages, isFalse);
    });

    test('reports unread', () {
      expect(_conversation().hasUnread, isTrue);
      expect(_conversation().copyWith(unreadCount: 0).hasUnread, isFalse);
    });

    test('compares on the fields the rail renders', () {
      expect(_conversation(), _conversation());
      expect(_conversation().hashCode, _conversation().hashCode);
      expect(_conversation(), isNot(_conversation().copyWith(unreadCount: 9)));
    });

    test('display name prefers the customer, then the subject', () {
      expect(_conversation().displayName, 'Ada');

      final withSubject = Conversation(
        id: 'c1',
        state: ConversationState.open,
        subject: 'Order #42',
        createdAt: testEpoch,
      );

      expect(withSubject.displayName, 'Order #42');
    });

    test('ignores a blank name or subject', () {
      final blank = Conversation(
        id: 'c1',
        state: ConversationState.open,
        customerName: '   ',
        subject: '',
        createdAt: testEpoch,
      );

      expect(blank.displayName, 'Unknown customer');
    });
  });

  group('Message', () {
    test('copyWith changes only what it is given', () {
      final updated = _message().copyWith(state: MessageState.delivered);

      expect(updated.state, MessageState.delivered);
      expect(updated.id, 'm1');
      expect(updated.body, 'hello');
    });

    test('copyWith can re-key to a server id', () {
      final rekeyed = _message().copyWith(id: 'server-1');

      expect(rekeyed.id, 'server-1');
      expect(rekeyed.conversationId, 'c1');
    });

    test('reports direction', () {
      expect(_message().isOutbound, isTrue);
      expect(_message().isInbound, isFalse);
    });

    test('reports whether it is still optimistic', () {
      expect(_message(state: MessageState.pending).isOptimistic, isTrue);
      expect(_message(state: MessageState.sending).isOptimistic, isTrue);
      expect(_message(state: MessageState.failed).isOptimistic, isTrue);
      expect(_message().isOptimistic, isFalse);
    });

    test('an inbound message is never optimistic', () {
      final inbound = Message(
        id: 'm1',
        conversationId: 'c1',
        direction: MessageDirection.inbound,
        state: MessageState.pending,
        createdAt: testEpoch,
      );

      expect(inbound.isOptimistic, isFalse);
    });

    test('reports whether it can be rendered', () {
      expect(_message().isRenderable, isTrue);

      final unknown = Message(
        id: 'm1',
        conversationId: 'c1',
        direction: MessageDirection.inbound,
        state: MessageState.delivered,
        type: 'sticker',
        createdAt: testEpoch,
      );

      expect(unknown.isRenderable, isFalse);
    });

    test('compares on the fields the bubble renders', () {
      expect(_message(), _message());
      expect(_message().hashCode, _message().hashCode);
      expect(_message(), isNot(_message(state: MessageState.read)));
    });
  });

  group('MessageState', () {
    test('reports which states the server has', () {
      expect(MessageState.sent.isConfirmed, isTrue);
      expect(MessageState.delivered.isConfirmed, isTrue);
      expect(MessageState.read.isConfirmed, isTrue);

      expect(MessageState.pending.isConfirmed, isFalse);
      expect(MessageState.sending.isConfirmed, isFalse);
      expect(MessageState.failed.isConfirmed, isFalse);
    });

    test('reports which states are still on their way out', () {
      expect(MessageState.pending.isInFlight, isTrue);
      expect(MessageState.sending.isInFlight, isTrue);
      expect(MessageState.failed.isInFlight, isFalse);
    });

    test('only a failed message offers a retry', () {
      expect(MessageState.failed.canRetry, isTrue);

      for (final state in MessageState.values) {
        if (state == MessageState.failed) continue;

        expect(state.canRetry, isFalse, reason: state.name);
      }
    });
  });

  group('MessageContent', () {
    test('trims and accepts a normal message', () {
      final result = MessageContent.parse('  hello  ') as ValidMessageContent;

      expect(result.content.value, 'hello');
    });

    test('collapses whitespace for the rail preview', () {
      final content = (MessageContent.parse(
        'line one\n\nline two',
      ) as ValidMessageContent).content;

      // A multi-line preview would stretch a list row or be cut mid-character.
      expect(content.preview(), 'line one line two');
    });

    test('truncates a long preview with an ellipsis', () {
      final content =
          (MessageContent.parse('x' * 200) as ValidMessageContent).content;

      final preview = content.preview(maxCharacters: 20);

      expect(preview.length, lessThanOrEqualTo(21));
      expect(preview, endsWith('…'));
    });

    test('leaves a short preview untouched', () {
      final content =
          (MessageContent.parse('short') as ValidMessageContent).content;

      expect(content.preview(), 'short');
    });

    test('rejects an empty or whitespace-only message', () {
      expect(
        (MessageContent.parse('') as InvalidMessageContent).error,
        MessageContentError.empty,
      );
      expect(
        (MessageContent.parse('   \n ') as InvalidMessageContent).error,
        MessageContentError.empty,
      );
    });

    test('rejects a message over the provider limit', () {
      expect(
        (MessageContent.parse(
          'x' * (MessageContent.maxLength + 1),
        ) as InvalidMessageContent).error,
        MessageContentError.tooLong,
      );
    });

    test('accepts a message at exactly the limit', () {
      expect(
        MessageContent.parse('x' * MessageContent.maxLength),
        isA<ValidMessageContent>(),
      );
    });
  });
}
