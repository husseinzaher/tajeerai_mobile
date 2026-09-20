import '../data/models/message_dto.dart';
import '../domain/entities/message.dart';

/// A decoded realtime message frame.
///
/// The socket layer hands up a name and an untyped map; this turns one into a
/// value the rest of the feature can act on, and rejects anything malformed
/// *here* rather than letting a broken payload reach the database.
sealed class MessageRealtimeEvent {
  const MessageRealtimeEvent();
}

/// A message arrived or changed.
final class MessageReceived extends MessageRealtimeEvent {
  const MessageReceived(this.message);

  final Message message;
}

/// A delivery receipt, with no body attached.
final class MessageStatusUpdated extends MessageRealtimeEvent {
  const MessageStatusUpdated(this.change);

  final MessageStatusChange change;
}

/// A message was withdrawn and should be removed locally.
final class MessageRemoved extends MessageRealtimeEvent {
  const MessageRemoved({required this.messageId, required this.conversationId});

  final String messageId;
  final String conversationId;
}

/// Somebody is composing.
///
/// Carries no `eventId`: it is never persisted, so there is nothing to
/// deduplicate and nothing to order.
///
/// **Two different frames arrive under this one name**, and they do not share
/// a field:
///
/// - *Another member of the workspace*, relayed by the gateway as
///   `{conversationId, userId, isTyping}`.
/// - *The customer*, reported by the provider as
///   `{conversationId, actor: 'customer', typing, expiresAt}`.
///
/// [isTyping] is decoded from whichever of the two boolean fields is present,
/// so a caller never has to know which side of the conversation it came from
/// -- and [actor] is how one that does care tells them apart.
final class TypingChanged extends MessageRealtimeEvent {
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
