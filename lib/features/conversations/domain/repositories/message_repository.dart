import '../entities/message.dart';
import '../value_objects/message_content.dart';

/// Data access for messages.
///
/// Same local-first contract as the conversation repository: [watchMessages]
/// reads the database only. History older than what is cached is fetched by
/// [loadOlder], which is an explicit call a controller makes when the reader
/// reaches the top -- not something a read does implicitly.
abstract interface class MessageRepository {
  /// A thread's messages, newest last, from local storage.
  Stream<List<Message>> watchMessages(String conversationId, {int limit});

  Future<Message?> findMessage(String messageId);

  /// Finds an optimistic row by its idempotency key.
  ///
  /// How an acknowledgement or a server broadcast is reconciled with the row
  /// already on screen, instead of appearing beside it as a duplicate.
  Future<Message?> findByClientMessageId(String clientMessageId);

  /// Writes an outbound message locally and queues it in the outbox.
  ///
  /// Returns immediately with the optimistic message. Durable before it is
  /// sent: killing the app between the tap and the acknowledgement must not
  /// lose what the user wrote.
  Future<Message> enqueueOutbound({
    required String conversationId,
    required MessageContent content,
    required String clientMessageId,
    String? authorId,
    String? authorName,
  });

  /// Applies messages that arrived over the socket or a sync.
  ///
  /// [eventAt] is the broadcast's `occurredAt`; rows carrying a newer one are
  /// left alone so a late frame cannot overwrite newer state.
  Future<int> upsertAll(List<Message> messages, {DateTime? eventAt});

  /// Moves a message to a new delivery state.
  Future<void> updateState({
    required String messageId,
    required MessageState state,
    String? externalId,
    String? failureReason,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? eventAt,
  });

  /// Replaces an optimistic row's local id with the server's, once known.
  ///
  /// Re-keying rather than inserting keeps the message in place in the list
  /// instead of having it disappear and reappear at the bottom.
  Future<void> reconcile({
    required String clientMessageId,
    required String serverMessageId,
    required MessageState state,
  });

  /// Fetches history older than [before] and writes it locally.
  Future<int> loadOlder({
    required String conversationId,
    required DateTime before,
    int limit,
  });

  /// Removes a message the server never accepted.
  Future<void> remove(String messageId);

  Future<void> loadLatest({required String conversationId}) async {}
}
