/// The conversation feature's realtime vocabulary.
///
/// **These names are the feature's business, not the transport's.** The socket
/// infrastructure forwards frames by name and knows none of them; this file is
/// where `conversation.updated` starts meaning something.
///
/// Transcribed from the backend's `REALTIME_EVENTS` and `SOCKET_COMMANDS`.
/// Keeping them as constants in one file is what makes a rename on the server
/// a one-line change here rather than a hunt through string literals.
abstract final class ConversationRealtimeEvents {
  // Server -> client, from `REALTIME_EVENTS`.
  static const String messageCreated = 'message.created';
  static const String messageUpdated = 'message.updated';

  /// A message the provider never accepted was thrown away -- drop the row.
  static const String messageRemoved = 'message.removed';

  static const String conversationCreated = 'conversation.created';
  static const String conversationUpdated = 'conversation.updated';
  static const String conversationStateChanged = 'conversation.state-changed';
  static const String unreadUpdated = 'conversation.unread-updated';
  static const String mediaReady = 'message.media-ready';

  /// Transient: never stored, and a client that misses one simply shows no
  /// bubble. Deliberately excluded from deduplication -- it carries no
  /// `eventId` because there is nothing to deduplicate.
  static const String typing = 'conversation.typing';

  /// Every frame this feature handles. Anything else on the socket belongs to
  /// another feature and is ignored here.
  static const Set<String> handled = <String>{
    messageCreated,
    messageUpdated,
    messageRemoved,
    mediaReady,
    conversationCreated,
    conversationUpdated,
    conversationStateChanged,
    unreadUpdated,
    typing,
  };
}
