import '../../../../infrastructure/realtime/socket_command.dart';
import '../../../../infrastructure/realtime/socket_exception.dart';
import '../../../../infrastructure/realtime/socket_manager.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../realtime/conversation_events.dart';
import '../models/conversation_dto.dart';
import '../models/message_dto.dart';

/// The conversation feature's socket commands.
///
/// **The socket is this feature's transport -- there is no HTTP here.**
/// Listing the rail, opening a thread, paging history, sending, syncing: all
/// of it goes over the connection the app already holds, which is what the
/// backend built `SOCKET_COMMANDS` for.
///
/// Every method here sends a command and decodes its acknowledgement. None of
/// them write to the database -- that is the repository's job, and keeping the
/// two apart is what lets a repository test drive a fake of this without a
/// socket.
///
/// ## The translation boundary
///
/// This is where `SocketException` stops. Every command goes through [_send],
/// which converts it to an `AppFailure` before returning -- so the repository,
/// the coordinators and the controllers above deal in the application's own
/// vocabulary and never import a transport's exception type. The architecture
/// guard enforces that (rule 27); this method is what makes obeying it
/// possible without every caller writing the same `try`.
class ConversationRemoteDataSource {
  const ConversationRemoteDataSource(this._socket);

  final SocketManager _socket;

  /// Sends a command, translating transport failures.
  ///
  /// `SocketFailure` keeps `code` and `isRetryable` from the original, which
  /// is what the outbox needs in order to decide between backing off and
  /// giving up -- without it having to know a socket exists.
  Future<SocketAckSuccess> _send(
    SocketCommand command, {
    Duration? timeout,
  }) async {
    try {
      return await _socket.send(command, timeout: timeout);
    } on SocketException catch (error) {
      throw error.toFailure();
    }
  }

  /// `conversation:list`. A cursor-paginated page of the rail.
  Future<ConversationPage> listConversations({
    int limit = 25,
    String? cursor,
    String? search,
    bool? archived,
  }) async {
    final ack = await _send(
      SocketCommand(
        name: ConversationCommands.list,
        payload: <String, Object?>{
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
          if (search != null && search.isNotEmpty) 'search': search,
          if (archived != null) 'archived': archived,
        },
      ),
    );

    final items = ack.data['items'] ?? ack.data['data'] ?? ack.rawData;

    return ConversationPage(
      conversations: _decodeConversations(items),
      nextCursor: ack.data['nextCursor']?.toString(),
      hasMore: ack.data['hasMore'] == true,
    );
  }

  /// `conversation:open`. Returns the thread and its newest page in one round
  /// trip, which is what the command exists for.
  Future<ConversationWithMessages> openConversation(
    String conversationId, {
    int messageLimit = 50,
  }) async {
    final ack = await _send(
      SocketCommand(
        name: ConversationCommands.open,
        payload: <String, Object?>{
          'conversationId': conversationId,
          'messageLimit': messageLimit,
        },
      ),
    );

    final conversation = ack.data['conversation'];

    return ConversationWithMessages(
      conversation: conversation is Map
          ? ConversationDto.decode(Map<String, Object?>.from(conversation))
          : null,
      messages: _decodeMessages(ack.data['messages'], conversationId),
    );
  }

  /// `message:list`. A page of history older than [before].
  Future<MessagePage> listMessages({
    required String conversationId,
    DateTime? before,
    int limit = 50,
  }) async {
    final ack = await _send(
      SocketCommand(
        name: ConversationCommands.messageList,
        payload: <String, Object?>{
          'conversationId': conversationId,
          if (before != null) 'before': before.toUtc().toIso8601String(),
          'limit': limit,
        },
      ),
    );

    return MessagePage(
      messages: _decodeMessages(
        ack.data['messages'] ?? ack.rawData,
        conversationId,
      ),
      nextCursor: ack.data['nextCursor']?.toString(),
      hasMore: ack.data['hasMore'] == true,
    );
  }

  /// `message:send`.
  ///
  /// [clientMessageId] is the idempotency key, generated before the first
  /// attempt and reused on every retry. The server answers with
  /// `deduplicated: true` when the command matched an earlier send and created
  /// nothing new -- which is exactly what makes a resend after a lost
  /// acknowledgement safe.
  Future<MessageSendResult> sendMessage({
    required String conversationId,
    required String body,
    required String clientMessageId,
  }) async {
    final ack = await _send(
      SocketCommand(
        name: ConversationCommands.messageSend,
        payload: <String, Object?>{
          'conversationId': conversationId,
          'body': body,
          'clientMessageId': clientMessageId,
        },
      ),
    );

    final messageId = ack.data['messageId']?.toString();

    if (messageId == null || messageId.isEmpty) {
      throw const FormatException('Send acknowledgement carried no id.');
    }

    return MessageSendResult(
      clientMessageId:
          ack.data['clientMessageId']?.toString() ?? clientMessageId,
      messageId: messageId,
      deduplicated: ack.data['deduplicated'] == true,
    );
  }

  /// `conversation:read`. Clears the unread count server-side.
  Future<void> markRead(String conversationId) async {
    await _send(
      SocketCommand(
        name: ConversationCommands.read,
        payload: <String, Object?>{'conversationId': conversationId},
      ),
    );
  }

  /// `conversation:sync`. Everything that changed since [since].
  ///
  /// The reconnect path. The server returns the *current state* of affected
  /// rows rather than replaying events, which is both smaller after a long
  /// absence and impossible to apply out of order.
  Future<RemoteSyncResult> synchronize({
    required DateTime since,
    String? conversationId,
  }) async {
    final ack = await _send(
      SocketCommand(
        name: ConversationCommands.sync,
        payload: <String, Object?>{
          'since': since.toUtc().toIso8601String(),
          if (conversationId != null) 'conversationId': conversationId,
        },
      ),
    );

    final syncedAt = ConversationDto.parseTime(ack.data['syncedAt']);

    return RemoteSyncResult(
      conversations: _decodeConversations(ack.data['conversations']),
      messages: _decodeMessages(ack.data['messages'], null),
      // Falling back to `since` rather than to now: advancing the cursor past
      // a window the server did not confirm would skip whatever happened in it.
      syncedAt: syncedAt ?? since,
      unreadTotal: _unreadTotal(ack.data['unread']),
    );
  }

  /// Asks the provider to show the customer a typing bubble.
  ///
  /// Fire-and-forget: a lost typing frame is invisible, and waiting on an
  /// acknowledgement per keystroke would be absurd.
  void sendTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) {
    _socket.emit(
      SocketCommand(
        name: ConversationCommands.typingIndicator,
        payload: <String, Object?>{
          'conversationId': conversationId,
          'isTyping': isTyping,
        },
      ),
    );
  }

  /// Decodes a list, skipping entries that are individually malformed.
  ///
  /// One bad row must not lose the other twenty-four in the page -- a partial
  /// rail is far better than an empty one.
  static List<Conversation> _decodeConversations(Object? raw) {
    if (raw is! List) return const <Conversation>[];

    final decoded = <Conversation>[];

    for (final entry in raw) {
      if (entry is! Map) continue;

      try {
        decoded.add(ConversationDto.decode(Map<String, Object?>.from(entry)));
      } on FormatException {
        continue;
      }
    }

    return decoded;
  }

  static List<Message> _decodeMessages(Object? raw, String? conversationId) {
    if (raw is! List) return const <Message>[];

    final decoded = <Message>[];

    for (final entry in raw) {
      if (entry is! Map) continue;

      try {
        decoded.add(
          MessageDto.decode(
            Map<String, Object?>.from(entry),
            conversationId: conversationId,
          ),
        );
      } on FormatException {
        continue;
      }
    }

    return decoded;
  }

  static int _unreadTotal(Object? raw) {
    if (raw is Map) {
      final total = raw['total'];

      if (total is int) return total;
    }

    return 0;
  }
}

/// A page of the rail.
final class ConversationPage {
  const ConversationPage({
    required this.conversations,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<Conversation> conversations;
  final String? nextCursor;
  final bool hasMore;
}

/// A page of a thread's history.
final class MessagePage {
  const MessagePage({
    required this.messages,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<Message> messages;
  final String? nextCursor;
  final bool hasMore;
}

/// What `conversation:open` returns.
final class ConversationWithMessages {
  const ConversationWithMessages({
    required this.conversation,
    required this.messages,
  });

  final Conversation? conversation;
  final List<Message> messages;
}

/// What `conversation:sync` returns.
final class RemoteSyncResult {
  const RemoteSyncResult({
    required this.conversations,
    required this.messages,
    required this.syncedAt,
    this.unreadTotal = 0,
  });

  final List<Conversation> conversations;
  final List<Message> messages;
  final DateTime syncedAt;
  final int unreadTotal;

  SyncOutcome toOutcome() => SyncOutcome(
    conversationsWritten: conversations.length,
    messagesWritten: messages.length,
    syncedAt: syncedAt,
  );
}

/// What `message:send` acknowledges with.
final class MessageSendResult {
  const MessageSendResult({
    required this.clientMessageId,
    required this.messageId,
    required this.deduplicated,
  });

  final String clientMessageId;
  final String messageId;

  /// True when the command matched an earlier send and created nothing new.
  final bool deduplicated;
}
