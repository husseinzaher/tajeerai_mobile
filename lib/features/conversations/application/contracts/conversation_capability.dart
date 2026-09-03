/// What other features may ask of Conversations.
///
/// The mirror of `SessionCapability`: a future Orders or Customers feature
/// that wants to open a thread depends on this interface, not on
/// `ConversationRepositoryImpl`, a DAO, or a conversation screen.
///
/// Kept deliberately small. A cross-feature contract that grows to expose the
/// whole feature is the coupling it was meant to prevent, wearing an
/// interface.
abstract interface class ConversationCapability {
  /// Threads with at least one unread message, for a badge.
  Stream<int> get unreadThreadCount;

  /// Whether a thread exists locally, for a caller deciding whether to deep
  /// link into it.
  Future<bool> hasConversation(String conversationId);
}
