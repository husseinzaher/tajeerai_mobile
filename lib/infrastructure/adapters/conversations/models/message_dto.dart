import '../../../../features/conversations/domain/entities/message.dart';
import 'conversation_dto.dart';

/// Decodes the backend's message payload.
///
/// Built against `MessageSocketEvent.message` and the pages
/// `message:list`/`conversation:open` acknowledge with.
abstract final class MessageDto {
  static Message decode(Map<String, Object?> json, {String? conversationId}) {
    final id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Message carried no id.');
    }

    final threadId = json['conversationId']?.toString() ?? conversationId;

    if (threadId == null || threadId.isEmpty) {
      throw const FormatException('Message carried no conversation.');
    }

    return Message(
      id: id,
      conversationId: threadId,
      clientMessageId: json['clientMessageId']?.toString(),
      direction: decodeDirection(json['direction']),
      state: decodeState(json['state']),
      type: json['type']?.toString() ?? 'text',
      body: json['body']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      authorName: json['authorName']?.toString(),
      authorId: json['authorId']?.toString(),
      isFromBot: json['isFromBot'] == true,
      failureReason: json['failureReason']?.toString(),
      externalId: json['externalId']?.toString(),
      createdAt:
          ConversationDto.parseTime(json['createdAt']) ??
          DateTime.now().toUtc(),
      updatedAt: ConversationDto.parseTime(json['updatedAt']),
      deliveredAt: ConversationDto.parseTime(json['deliveredAt']),
      readAt: ConversationDto.parseTime(json['readAt']),
      queuedAt: ConversationDto.parseTime(json['queuedAt']),
    );
  }

  /// Unwraps `{eventId, occurredAt, conversationId, message: {...}}`.
  static Message decodeEvent(Map<String, Object?> json) {
    final message = json['message'];

    if (message is! Map) {
      throw const FormatException('Event carried no message.');
    }

    return decode(
      Map<String, Object?>.from(message),
      conversationId: json['conversationId']?.toString(),
    );
  }

  static MessageDirection decodeDirection(Object? raw) {
    return raw?.toString().toLowerCase() == 'inbound'
        ? MessageDirection.inbound
        : MessageDirection.outbound;
  }

  /// Maps the server's delivery vocabulary onto [MessageState].
  ///
  /// `queued` becomes [MessageState.sending] rather than
  /// [MessageState.pending]: the server has the message, it is simply waiting
  /// on a worker, and showing it as "not sent yet" would invite the operator
  /// to send it twice.
  static MessageState decodeState(Object? raw) {
    return switch (raw?.toString().toLowerCase()) {
      'pending' => MessageState.pending,
      'queued' || 'sending' => MessageState.sending,
      'failed' => MessageState.failed,
      'sent' || 'accepted' => MessageState.sent,
      'delivered' => MessageState.delivered,
      'read' => MessageState.read,
      'discarded' || 'deleted' || 'revoked' => MessageState.discarded,
      // Unknown but present on the server: treat as sent, never as failed. A
      // false failure invites a duplicate send; a false "sent" does not.
      _ => MessageState.sent,
    };
  }
}
