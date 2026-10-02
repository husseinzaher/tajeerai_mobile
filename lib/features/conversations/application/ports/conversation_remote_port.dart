import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/conversation_repository.dart';

/// What this feature asks of the server, in the feature's own vocabulary.
///
/// An application port. The outbox, the presence coordinator and both
/// repository implementations all talk to the server, and none of them may
/// know that the server is reached over Socket.IO -- a coordinator that named
/// the transport could only ever be tested against that transport. So they
/// depend on this, and `ConversationRemoteDataSource` in
/// `infrastructure/adapters/conversations/` is the one class that knows what a
/// socket command is.
///
/// Every method answers in domain entities or in the plain result types
/// below, and throws `AppFailure` -- never a transport exception. The adapter
/// is where `SocketException` stops.
abstract interface class ConversationRemotePort {
  /// A cursor-paginated page of the rail.
  Future<ConversationPage> listConversations({
    int limit = 25,
    String? cursor,
    String? search,
    bool? archived,
  });

  /// The thread and its newest page, in one round trip.
  Future<ConversationWithMessages> openConversation(
    String conversationId, {
    int messageLimit = 50,
  });

  /// A page of history older than [before]; the newest page when it is null.
  Future<MessagePage> listMessages({
    required String conversationId,
    DateTime? before,
    int limit = 50,
  });

  /// Sends a message. [clientMessageId] is the idempotency key, generated
  /// before the first attempt and reused on every retry.
  Future<MessageSendResult> sendMessage({
    required String conversationId,
    required String clientMessageId,
    String type = 'text',
    String? body,
    String? mediaId,
    String? filename,
    String? mimeType,
  });

  /// Clears the unread count server-side.
  Future<void> markRead(String conversationId);

  /// Throws away a message the provider never accepted.
  Future<void> discardMessage({
    required String conversationId,
    required String messageId,
  });

  /// Takes a seat in the thread's room, and gives it up again.
  Future<void> joinConversation(String conversationId);

  Future<void> leaveConversation(String conversationId);

  /// Everything that changed since [since]: the reconnect path.
  Future<RemoteSyncResult> synchronize({
    required DateTime since,
    String? conversationId,
  });

  /// Asks the provider to show the customer a typing bubble. Fire-and-forget.
  void sendTypingIndicator({required String conversationId});
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

/// What opening a thread returns.
final class ConversationWithMessages {
  const ConversationWithMessages({
    required this.conversation,
    required this.messages,
  });

  final Conversation? conversation;
  final List<Message> messages;
}

/// What a synchronisation pass returns.
final class RemoteSyncResult {
  const RemoteSyncResult({
    required this.conversations,
    required this.messages,
    required this.syncedAt,
    this.unreadTotal = 0,
  });

  final List<Conversation> conversations;
  final List<Message> messages;

  /// The server's own cursor for the next pass -- never the device clock.
  final DateTime syncedAt;
  final int unreadTotal;

  SyncOutcome toOutcome() => SyncOutcome(
    conversationsWritten: conversations.length,
    messagesWritten: messages.length,
    syncedAt: syncedAt,
  );
}

/// What a send acknowledges with.
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
