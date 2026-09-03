import '../entities/conversation.dart';

/// Data access for conversations.
///
/// Reads are **local-first by contract**: [watchConversations] observes the
/// database and never touches the network, so a screen bound to it renders
/// offline and updates when a socket event lands. Synchronisation is a
/// separate verb, called by a coordinator, not implied by reading.
///
/// That separation is the offline-first architecture expressed as a type: a
/// caller cannot accidentally make opening a screen a network round trip,
/// because the read method has no way to perform one.
abstract interface class ConversationRepository {
  /// The rail, from local storage, re-emitting on every change.
  Stream<List<Conversation>> watchConversations({
    bool includeArchived = false,
    String? searchTerm,
    int limit = 50,
  });

  /// One conversation, from local storage.
  Stream<Conversation?> watchConversation(String conversationId);

  Future<Conversation?> findConversation(String conversationId);

  /// Fetches a page from the server and writes it locally.
  ///
  /// Returns the number of rows written. Called by the sync coordinator, never
  /// by a screen.
  Future<int> synchronizeList({int limit, String? cursor});

  /// Applies everything that changed since [since].
  ///
  /// Maps to the backend's `conversation:sync`, which returns current rows
  /// rather than an event replay -- smaller after a long absence, and
  /// impossible to apply out of order.
  Future<SyncOutcome> synchronizeSince(
    DateTime since, {
    String? conversationId,
  });

  /// Writes conversations that arrived over the socket.
  Future<void> upsertAll(List<Conversation> conversations, {DateTime? eventAt});

  /// Marks a thread read locally and tells the server.
  Future<void> markRead(String conversationId);

  /// Clears everything. Used on sign-out.
  Future<void> clear();
}

/// What one synchronisation pass achieved.
final class SyncOutcome {
  const SyncOutcome({
    required this.conversationsWritten,
    required this.messagesWritten,
    required this.syncedAt,
  });

  final int conversationsWritten;
  final int messagesWritten;

  /// The server's own `syncedAt`, to be stored as the next cursor.
  ///
  /// Never the device clock: a phone running fast would skip the window
  /// between the two.
  final DateTime syncedAt;
}
