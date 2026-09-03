/// Facts the Conversations feature announces.
///
/// Published rather than called: the app shell listens for
/// [ConversationMessageArrived] to update a badge without the conversations
/// feature knowing a badge exists.
sealed class ConversationAppEvent {
  const ConversationAppEvent();
}

/// A message arrived from the server and was persisted.
final class ConversationMessageArrived extends ConversationAppEvent {
  const ConversationMessageArrived({
    required this.conversationId,
    required this.isInbound,
  });

  final String conversationId;
  final bool isInbound;
}

/// A synchronisation pass finished.
final class ConversationSyncCompleted extends ConversationAppEvent {
  const ConversationSyncCompleted({
    required this.syncedAt,
    required this.conversationsWritten,
    required this.messagesWritten,
  });

  final DateTime syncedAt;
  final int conversationsWritten;
  final int messagesWritten;
}

/// A queued mutation gave up. The UI offers a retry on the strength of this.
final class ConversationMutationFailed extends ConversationAppEvent {
  const ConversationMutationFailed({
    required this.outboxId,
    required this.reason,
  });

  final String outboxId;

  /// Non-sensitive. Never a message body.
  final String reason;
}
