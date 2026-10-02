/// Somebody is composing in a thread.
///
/// The one piece of realtime state that is never written to the database: it
/// is true for a few seconds and then it is not, and persisting something that
/// expires that fast would be a write per keystroke, per agent. The realtime
/// adapter decodes the frame into this and publishes it; the thread's
/// controller shows and expires the bubble.
///
/// An application event rather than a wire type, which is why the adapter's
/// payload shape stops at the adapter. **Two different frames arrive under the
/// server's one name**, and they do not share a field:
///
/// - *Another member of the workspace*, relayed by the gateway as
///   `{conversationId, userId, isTyping}`.
/// - *The customer*, reported by the provider as
///   `{conversationId, actor: 'customer', typing, expiresAt}`.
///
/// [isTyping] is decoded from whichever of the two boolean fields is present,
/// so a consumer never has to know which side of the conversation it came from
/// -- and [actor] is how one that does care tells them apart.
final class TypingChanged {
  const TypingChanged({
    required this.conversationId,
    required this.isTyping,
    this.userId,
    this.actor,
    this.expiresAt,
  });

  final String conversationId;
  final bool isTyping;

  /// The member who is typing, on the agent-to-agent frame. Null on the
  /// customer's, which carries no user.
  final String? userId;

  /// `'customer'` when the provider reported it; null when a member did.
  final String? actor;

  /// When to stop showing the bubble without being told to.
  ///
  /// The frame that *clears* a bubble is the one most likely to be lost -- a
  /// locked phone, a dropped provider session -- and a bubble that never goes
  /// away is worse than no bubble at all. Null on the agent frame, which the
  /// reader expires on its own short timer instead.
  final DateTime? expiresAt;

  /// Whether this is the person on the other side of the conversation.
  bool get isCustomer => actor == 'customer';
}
