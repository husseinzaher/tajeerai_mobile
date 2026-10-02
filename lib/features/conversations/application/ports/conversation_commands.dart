/// The commands this feature sends the server, by the names the backend's
/// `SOCKET_COMMANDS` gives them.
///
/// Application-level on purpose, though the names are the wire's. Two things
/// read them: the adapter that puts a command on the socket, and the outbox,
/// which stores a command's name beside its payload so a queued mutation can
/// be dispatched after the process that queued it has died. The outbox is an
/// application concern -- *which* mutations are queued and how they are
/// retried is the feature's business -- so the vocabulary it keys on lives
/// here, and the adapter imports it rather than the other way round.
///
/// Keeping them as constants in one file is what makes a rename on the server
/// a one-line change here rather than a hunt through string literals.
abstract final class ConversationCommands {
  static const String list = 'conversation:list';
  static const String open = 'conversation:open';
  static const String read = 'conversation:read';
  static const String unread = 'conversation:unread';
  static const String sync = 'conversation:sync';
  static const String archive = 'conversation:archive';
  static const String pin = 'conversation:pin';

  static const String messageList = 'message:list';
  static const String messageSend = 'message:send';
  static const String messageRetry = 'message:retry';
  static const String messageDiscard = 'message:discard';

  /// Asks the provider to show the customer a typing bubble. Distinct from the
  /// agent-to-agent `conversation.typing` broadcast.
  static const String typingIndicator = 'conversation:typing-indicator';

  /// Takes a seat in the thread, and gives it up again.
  ///
  /// Dot-separated rather than colon-separated, unlike every command above it:
  /// that is the backend's spelling for these two, not a slip here.
  ///
  /// **These are not optional.** The server sends delivery ticks, media URLs,
  /// withdrawals and typing to the conversation room *only* -- a client that
  /// never joins receives a thread that looks live because new messages still
  /// arrive on the inbox audience, and is silently missing everything else.
  /// The seat also tells the server not to push a notification for a thread
  /// the member is already looking at.
  static const String join = 'conversation.join';
  static const String leave = 'conversation.leave';
}
