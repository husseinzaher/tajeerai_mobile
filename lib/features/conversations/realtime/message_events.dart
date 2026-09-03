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
final class TypingChanged extends MessageRealtimeEvent {
  const TypingChanged({
    required this.conversationId,
    required this.isTyping,
    this.userId,
  });

  final String conversationId;
  final bool isTyping;
  final String? userId;
}
