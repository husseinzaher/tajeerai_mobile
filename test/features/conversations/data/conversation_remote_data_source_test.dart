import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/data/remote/conversation_remote_data_source.dart';
import 'package:TajeerAi/features/conversations/realtime/conversation_events.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/realtime/connection/reconnect_policy.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_command.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_exception.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_manager.dart';

import '../../../infrastructure/realtime/fakes/fake_socket_client.dart';
import '../../../support/fixed_clock.dart';

/// Drives the data source over a real [SocketManager] with a fake transport.
///
/// The manager is real so the command path is the production one; only the
/// socket underneath is replaced. That is what makes these assertions about
/// the *backend contract* rather than about a mock.
void main() {
  late FakeSocketClient client;
  late SocketManager manager;
  late ConversationRemoteDataSource remote;

  setUp(() async {
    client = FakeSocketClient();

    manager = SocketManager(
      client: client,
      credentials: FakeCredentials(),
      logger: Logger('test', verbose: false),
      policy: const ReconnectPolicy(
        initialDelay: Duration(milliseconds: 1),
        maxDelay: Duration(milliseconds: 2),
      ),
    );

    await manager.start();
    remote = ConversationRemoteDataSource(manager);
  });

  tearDown(() => manager.dispose());

  SocketCommand lastCommand() => client.sentCommands.last;

  group('conversation:list', () {
    test('sends the command the backend declares', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'items': <Object?>[],
      });

      await remote.listConversations(limit: 10, search: 'ada');

      expect(lastCommand().name, ConversationCommands.list);
      expect(lastCommand().payload['limit'], 10);
      expect(lastCommand().payload['search'], 'ada');
    });

    test('omits filters that were not asked for', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{});

      await remote.listConversations();

      // `z.object` strips what it does not declare, so sending a null filter
      // is harmless -- but omitting it keeps the frame honest.
      expect(lastCommand().payload.containsKey('search'), isFalse);
      expect(lastCommand().payload.containsKey('cursor'), isFalse);
      expect(lastCommand().payload.containsKey('archived'), isFalse);
    });

    test('decodes the page the backend actually returns', () async {
      // `toCursorPage` returns `{data, meta:{hasMore, nextCursor}}`. Reading
      // the pagination from the top level silently disabled paging past the
      // first page.
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'state': 'open',
            'createdAt': '2026-03-01T12:00:00.000Z',
          },
        ],
        'meta': <String, Object?>{
          'nextCursor': 'cursor-1',
          'hasMore': true,
          'total': 42,
        },
      });

      final page = await remote.listConversations();

      expect(page.conversations.single.id, 'c1');
      expect(page.nextCursor, 'cursor-1');
      expect(page.hasMore, isTrue);
    });

    test('still reads a flat page shape', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'state': 'open',
            'createdAt': '2026-03-01T12:00:00.000Z',
          },
        ],
        'nextCursor': 'cursor-1',
        'hasMore': true,
      });

      final page = await remote.listConversations();

      expect(page.nextCursor, 'cursor-1');
      expect(page.hasMore, isTrue);
    });

    test('skips a malformed row rather than losing the page', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{'no': 'id'},
          <String, Object?>{
            'id': 'c2',
            'state': 'open',
            'createdAt': '2026-03-01T12:00:00.000Z',
          },
        ],
      });

      final page = await remote.listConversations();

      // A partial rail is far better than an empty one.
      expect(page.conversations.map((c) => c.id), <String>['c2']);
    });

    test('returns an empty page when the payload is not a list', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'data': 'unexpected',
      });

      expect((await remote.listConversations()).conversations, isEmpty);
    });
  });

  group('conversation:open', () {
    test('asks for the thread and its newest page in one round trip', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'conversation': <String, Object?>{
          'id': 'c1',
          'state': 'open',
          'createdAt': '2026-03-01T12:00:00.000Z',
        },
        'messages': <Object?>[],
      });

      final result = await remote.openConversation('c1', messageLimit: 25);

      expect(lastCommand().name, ConversationCommands.open);
      expect(lastCommand().payload['conversationId'], 'c1');
      expect(lastCommand().payload['messageLimit'], 25);
      expect(result.conversation!.id, 'c1');
    });
  });

  group('message:list', () {
    test('sends the cursor as an ISO timestamp', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'messages': <Object?>[],
      });

      await remote.listMessages(conversationId: 'c1', before: testEpoch);

      expect(lastCommand().name, ConversationCommands.messageList);
      expect(lastCommand().payload['before'], testEpoch.toIso8601String());
    });

    test('omits the cursor on a first page', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{});

      await remote.listMessages(conversationId: 'c1');

      expect(lastCommand().payload.containsKey('before'), isFalse);
    });
  });

  group('message:send', () {
    test('carries the idempotency key', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'clientMessageId': 'client-1',
        'messageId': 'server-1',
        'deduplicated': false,
      });

      final result = await remote.sendMessage(
        conversationId: 'c1',
        body: 'hello',
        clientMessageId: 'client-1',
      );

      expect(lastCommand().name, ConversationCommands.messageSend);
      expect(lastCommand().payload['clientMessageId'], 'client-1');
      expect(result.messageId, 'server-1');
      expect(result.deduplicated, isFalse);
    });

    test('reports a deduplicated send', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'messageId': 'server-1',
        'deduplicated': true,
      });

      final result = await remote.sendMessage(
        conversationId: 'c1',
        body: 'hello',
        clientMessageId: 'client-1',
      );

      expect(result.deduplicated, isTrue);
    });

    test('carries media fields for an attachment send', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'messageId': 'server-1',
        'deduplicated': false,
      });

      await remote.sendMessage(
        conversationId: 'c1',
        clientMessageId: 'client-1',
        type: 'image',
        mediaId: 'media-1',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        body: 'caption',
      );

      expect(lastCommand().payload['type'], 'image');
      expect(lastCommand().payload['mediaId'], 'media-1');
      expect(lastCommand().payload['filename'], 'photo.jpg');
      expect(lastCommand().payload['body'], 'caption');
    });

    test('rejects an acknowledgement with no message id', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{});

      await expectLater(
        remote.sendMessage(
          conversationId: 'c1',
          body: 'hello',
          clientMessageId: 'client-1',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('conversation:sync', () {
    test('sends the cursor and decodes the result', () async {
      final serverTime = testEpoch.add(const Duration(minutes: 5));

      client.nextAck = SocketAckSuccess(<String, Object?>{
        'conversations': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'state': 'open',
            'createdAt': '2026-03-01T12:00:00.000Z',
          },
        ],
        'messages': <Object?>[],
        'unread': <String, Object?>{'total': 4},
        'syncedAt': serverTime.toIso8601String(),
      });

      final result = await remote.synchronize(since: testEpoch);

      expect(lastCommand().name, ConversationCommands.sync);
      expect(lastCommand().payload['since'], testEpoch.toIso8601String());
      expect(result.conversations, hasLength(1));
      expect(result.syncedAt, serverTime);
      expect(result.unreadTotal, 4);
    });

    test('falls back to the requested window when the server sends no stamp', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{
        'conversations': <Object?>[],
        'messages': <Object?>[],
      });

      final result = await remote.synchronize(since: testEpoch);

      // Advancing past a window the server did not confirm would skip whatever
      // happened in it.
      expect(result.syncedAt, testEpoch);
    });

    test('converts to a domain outcome', () async {
      client.nextAck = SocketAckSuccess(<String, Object?>{
        'conversations': <Object?>[],
        'messages': <Object?>[],
        'syncedAt': testEpoch.toIso8601String(),
      });

      final outcome = (await remote.synchronize(since: testEpoch)).toOutcome();

      expect(outcome.syncedAt, testEpoch);
      expect(outcome.conversationsWritten, 0);
    });
  });

  group('conversation:read', () {
    test('names the thread', () async {
      client.nextAck = const SocketAckSuccess(<String, Object?>{});

      await remote.markRead('c1');

      expect(lastCommand().name, ConversationCommands.read);
      expect(lastCommand().payload['conversationId'], 'c1');
    });
  });

  group('typing indicator', () {
    test('is fire-and-forget', () async {
      remote.sendTypingIndicator(conversationId: 'c1', isTyping: true);

      // Waiting on an acknowledgement per keystroke would be absurd.
      expect(
        client.emittedCommands.single.name,
        ConversationCommands.typingIndicator,
      );
      expect(client.sentCommands, isEmpty);
    });
  });

  group('the translation boundary', () {
    test(
      'a server rejection becomes an AppFailure, not a SocketException',
      () async {
        client.sendFailure = const SocketException(
          message: 'Already archived.',
          code: 'CONFLICT',
        );

        await expectLater(
          remote.markRead('c1'),
          throwsA(allOf(isA<ConflictFailure>(), isNot(isA<SocketException>()))),
        );
      },
    );

    test('a transport failure keeps its retryability', () async {
      client.sendFailure = const SocketException(
        message: 'Timed out.',
        code: 'TIMEOUT',
      );

      await expectLater(
        remote.listConversations(),
        throwsA(
          isA<SocketFailure>().having(
            (f) => f.isRetryable,
            'isRetryable',
            isTrue,
          ),
        ),
      );
    });

    test('a validation rejection carries its field details across', () async {
      client.sendFailure = const SocketException(
        message: 'Invalid.',
        code: 'VALIDATION_FAILED',
        details: <String, List<String>>{
          'body': <String>['too long'],
        },
      );

      await expectLater(
        remote.sendMessage(
          conversationId: 'c1',
          body: 'x',
          clientMessageId: 'client-1',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.errorsFor('body'),
            'body errors',
            <String>['too long'],
          ),
        ),
      );
    });
  });
}
