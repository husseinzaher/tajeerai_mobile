import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/conversations/data/models/conversation_dto.dart';
import 'package:tajeerai_mobile/features/conversations/data/models/message_dto.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';

void main() {
  group('ConversationDto', () {
    test('decodes the backend payload', () {
      final conversation = ConversationDto.decode(<String, Object?>{
        'id': 'c1',
        'state': 'open',
        'channelId': 'ch1',
        'customerId': 'cu1',
        'assigneeId': 'u1',
        'unreadCount': 3,
        'subject': 'Order #42',
        'isBotEnabled': true,
        'tags': <Object?>['vip'],
        'lastMessageAt': '2026-03-01T12:00:00.000Z',
        'createdAt': '2026-02-01T09:00:00.000Z',
      });

      expect(conversation.id, 'c1');
      expect(conversation.state, ConversationState.open);
      expect(conversation.unreadCount, 3);
      expect(conversation.tags, <String>['vip']);
      expect(conversation.isBotEnabled, isTrue);
      expect(conversation.lastMessageAt, DateTime.utc(2026, 3, 1, 12));
    });

    test('unwraps the event envelope', () {
      final conversation = ConversationDto.decodeEvent(<String, Object?>{
        'eventId': 'e1',
        'occurredAt': '2026-03-01T12:00:00.000Z',
        'conversation': <String, Object?>{
          'id': 'c1',
          'state': 'closed',
          'createdAt': '2026-02-01T09:00:00.000Z',
        },
      });

      expect(conversation.id, 'c1');
      expect(conversation.state, ConversationState.closed);
    });

    test('maps every documented state', () {
      const expected = <String, ConversationState>{
        'open': ConversationState.open,
        'pending': ConversationState.pending,
        'closed': ConversationState.closed,
        'archived': ConversationState.archived,
      };

      expected.forEach((raw, state) {
        expect(ConversationDto.decodeState(raw), state, reason: raw);
      });
    });

    test('degrades an unknown state to open rather than throwing', () {
      // The server's vocabulary can grow; a client that crashes on an
      // unrecognised value fails much worse than one that shows it as open.
      expect(
        ConversationDto.decodeState('some-new-state'),
        ConversationState.open,
      );
      expect(ConversationDto.decodeState(null), ConversationState.open);
    });

    test('reads the customer name from either payload shape', () {
      final nested = ConversationDto.decode(<String, Object?>{
        'id': 'c1',
        'state': 'open',
        'createdAt': '2026-02-01T09:00:00.000Z',
        'customer': <String, Object?>{'displayName': 'Ada'},
      });

      final flat = ConversationDto.decode(<String, Object?>{
        'id': 'c2',
        'state': 'open',
        'createdAt': '2026-02-01T09:00:00.000Z',
        'customerName': 'Grace',
      });

      // One shape must not blank the rail.
      expect(nested.customerName, 'Ada');
      expect(flat.customerName, 'Grace');
    });

    test('reads tags whether they are strings or objects', () {
      final conversation = ConversationDto.decode(<String, Object?>{
        'id': 'c1',
        'state': 'open',
        'createdAt': '2026-02-01T09:00:00.000Z',
        'tags': <Object?>[
          'plain',
          <String, Object?>{'name': 'objectShaped'},
        ],
      });

      expect(conversation.tags, <String>['plain', 'objectShaped']);
    });

    test('rejects a payload with no id', () {
      expect(
        () => ConversationDto.decode(<String, Object?>{'state': 'open'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('tolerates every optional field being absent', () {
      final conversation = ConversationDto.decode(<String, Object?>{
        'id': 'c1',
        'state': 'open',
      });

      // A field the server adds must not break decoding, and a missing
      // optional must not throw.
      expect(conversation.unreadCount, 0);
      expect(conversation.tags, isEmpty);
      expect(conversation.customerName, isNull);
      expect(conversation.displayName, 'Unknown customer');
    });

    group('the rail payload, as the backend actually sends it', () {
      /// One row from `conversation:list`, in the shape
      /// `ConversationService.list` builds.
      Map<String, Object?> railRow({
        Object? pinnedAt,
        Object? archivedAt,
        List<Object?>? messages,
      }) {
        return <String, Object?>{
          'id': 'c1',
          'state': 'open',
          'unreadCount': 2,
          'createdAt': '2026-02-01T09:00:00.000Z',
          'lastMessageAt': '2026-03-01T12:00:00.000Z',
          'pinnedAt': pinnedAt,
          'archivedAt': archivedAt,
          'muted': false,
          'tags': <Object?>[],
          'customer': <String, Object?>{
            'id': 'cu1',
            'name': 'Ada Lovelace',
            'phone': '+201000000000',
            'photoUrl': 'https://cdn.test/ada.png',
          },
          'messages': messages ?? <Object?>[],
        };
      }

      test('takes the preview from the attached latest message', () {
        // Regression: the backend attaches the newest message as a
        // one-element `messages` array and sends no `lastMessagePreview`.
        // Reading a preview field produced an Inbox where every row said
        // "No messages yet" -- confirmed on a real device.
        final conversation = ConversationDto.decode(
          railRow(
            messages: <Object?>[
              <String, Object?>{'id': 'm1', 'body': 'See you then'},
            ],
          ),
        );

        expect(conversation.lastMessagePreview, 'See you then');
      });

      test('collapses whitespace in the preview', () {
        final conversation = ConversationDto.decode(
          railRow(
            messages: <Object?>[
              <String, Object?>{'id': 'm1', 'body': 'line one\n\nline two'},
            ],
          ),
        );

        expect(conversation.lastMessagePreview, 'line one line two');
      });

      test('names an attachment when the latest message has no body', () {
        final conversation = ConversationDto.decode(
          railRow(
            messages: <Object?>[
              <String, Object?>{
                'id': 'm1',
                'body': null,
                'mediaUrl': 'https://cdn.test/a.jpg',
              },
            ],
          ),
        );

        expect(conversation.lastMessagePreview, 'Attachment');
      });

      test('has no preview for a thread with no messages', () {
        expect(ConversationDto.decode(railRow()).lastMessagePreview, isNull);
      });

      test('reads pinned and archived from their timestamps', () {
        // The rail sends `pinnedAt` / `archivedAt`, not booleans. Reading
        // `pinned` / `archived` meant a pinned thread never sorted to the top.
        final pinned = ConversationDto.decode(
          railRow(pinnedAt: '2026-03-01T10:00:00.000Z'),
        );
        final archived = ConversationDto.decode(
          railRow(archivedAt: '2026-03-01T10:00:00.000Z'),
        );
        final plain = ConversationDto.decode(railRow());

        expect(pinned.isPinned, isTrue);
        expect(archived.isArchived, isTrue);
        expect(archived.acceptsNewMessages, isFalse);
        expect(plain.isPinned, isFalse);
        expect(plain.isArchived, isFalse);
      });

      test('reads the customer name and resolved photo', () {
        final conversation = ConversationDto.decode(railRow());

        expect(conversation.customerName, 'Ada Lovelace');
        expect(conversation.displayName, 'Ada Lovelace');
        expect(conversation.customerAvatarUrl, 'https://cdn.test/ada.png');
      });

      test('takes muted as the server resolved it', () {
        // "Muted until a time that has passed" is not muted, and the backend
        // declines to make every client re-implement that comparison.
        final row = railRow()..['muted'] = true;

        expect(ConversationDto.decode(row).isMuted, isTrue);
      });
    });

    test('normalises timestamps to UTC', () {
      final conversation = ConversationDto.decode(<String, Object?>{
        'id': 'c1',
        'state': 'open',
        'createdAt': '2026-03-01T14:00:00+02:00',
      });

      // Local and server timestamps get compared; mixing zones makes ordering
      // wrong by hours.
      expect(conversation.createdAt.isUtc, isTrue);
      expect(conversation.createdAt, DateTime.utc(2026, 3, 1, 12));
    });
  });

  group('MessageDto', () {
    test('decodes the backend payload', () {
      final message = MessageDto.decode(<String, Object?>{
        'id': 'm1',
        'conversationId': 'c1',
        'direction': 'inbound',
        'type': 'text',
        'state': 'delivered',
        'body': 'hello',
        'createdAt': '2026-03-01T12:00:00.000Z',
        'isFromBot': false,
      });

      expect(message.id, 'm1');
      expect(message.direction, MessageDirection.inbound);
      expect(message.state, MessageState.delivered);
      expect(message.body, 'hello');
    });

    test('takes the conversation id from the envelope when absent', () {
      final message = MessageDto.decode(<String, Object?>{
        'id': 'm1',
        'direction': 'outbound',
        'state': 'sent',
        'createdAt': '2026-03-01T12:00:00.000Z',
      }, conversationId: 'from-envelope');

      expect(message.conversationId, 'from-envelope');
    });

    test('maps queued to sending, not pending', () {
      // The server has the message; showing it as "not sent yet" would invite
      // the operator to send it twice.
      expect(MessageDto.decodeState('queued'), MessageState.sending);
    });

    test('maps every documented delivery state', () {
      const expected = <String, MessageState>{
        'pending': MessageState.pending,
        'sending': MessageState.sending,
        'failed': MessageState.failed,
        'sent': MessageState.sent,
        'delivered': MessageState.delivered,
        'read': MessageState.read,
        'discarded': MessageState.discarded,
      };

      expected.forEach((raw, state) {
        expect(MessageDto.decodeState(raw), state, reason: raw);
      });
    });

    test('degrades an unknown state to sent, never to failed', () {
      // A false failure invites a duplicate send; a false "sent" does not.
      expect(MessageDto.decodeState('brand-new-state'), MessageState.sent);
    });

    test('rejects a message with no id', () {
      expect(
        () => MessageDto.decode(<String, Object?>{'conversationId': 'c1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a message with no conversation', () {
      expect(
        () => MessageDto.decode(<String, Object?>{'id': 'm1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodes a status event without a body', () {
      final change = MessageDto.decodeStatusEvent(<String, Object?>{
        'eventId': 'e1',
        'conversationId': 'c1',
        'messageId': 'm1',
        'state': 'read',
        'readAt': '2026-03-01T12:05:00.000Z',
        'externalId': 'wamid.123',
      });

      expect(change.messageId, 'm1');
      expect(change.state, MessageState.read);
      expect(change.externalId, 'wamid.123');
      expect(change.readAt, DateTime.utc(2026, 3, 1, 12, 5));
    });

    test('rejects a status event with no message id', () {
      expect(
        () => MessageDto.decodeStatusEvent(<String, Object?>{'state': 'read'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
