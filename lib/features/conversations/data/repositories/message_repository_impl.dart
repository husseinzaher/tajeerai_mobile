import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/app_database.dart';
import '../../../../infrastructure/database/daos/outbox_dao.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/value_objects/message_content.dart';
import '../../realtime/conversation_events.dart';
import '../local/conversation_dao.dart';
import '../local/conversation_tables.dart';
import '../remote/conversation_remote_data_source.dart';

/// The [MessageRepository] implementation.
///
/// The interesting method is [enqueueOutbound], which is where offline writes
/// actually happen: the message row and its outbox entry are written in **one
/// transaction**, so the app can die between them without leaving a message
/// that will never send or a queued command with no message to show for it.
class MessageRepositoryImpl implements MessageRepository {
  MessageRepositoryImpl({
    required ConversationDao dao,
    required OutboxDao outbox,
    required ConversationRemoteDataSource remote,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
  }) : _dao = dao,
       _outbox = outbox,
       _remote = remote,
       _logger = logger,
       _clock = clock;

  final ConversationDao _dao;
  final OutboxDao _outbox;
  final ConversationRemoteDataSource _remote;
  final Logger _logger;
  final DateTime Function() _clock;

  @override
  Stream<List<Message>> watchMessages(String conversationId, {int limit = 50}) {
    return _dao
        .watchMessages(conversationId, limit: limit)
        .map((rows) => rows.map<Message>(_toEntity).toList(growable: false));
  }

  @override
  Future<Message?> findMessage(String messageId) async {
    final row = await _dao.findMessage(messageId);

    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Message?> findByClientMessageId(String clientMessageId) async {
    final row = await _dao.findByClientMessageId(clientMessageId);

    return row == null ? null : _toEntity(row);
  }

  /// Writes the message and queues the command atomically.
  ///
  /// The row is keyed by [clientMessageId] until the server assigns an id, so
  /// the optimistic bubble has a stable identity from the moment it is drawn
  /// and does not jump when the acknowledgement lands.
  @override
  Future<Message> enqueueOutbound({
    required String conversationId,
    required MessageContent content,
    required String clientMessageId,
    String? authorId,
    String? authorName,
  }) async {
    final now = _clock().toUtc();

    final message = Message(
      id: clientMessageId,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      direction: MessageDirection.outbound,
      state: MessageState.pending,
      body: content.value,
      authorId: authorId,
      authorName: authorName,
      createdAt: now,
    );

    try {
      await _dao.transaction(() async {
        await _dao.upsertMessage(_toCompanion(message));

        await _outbox.enqueue(
          id: clientMessageId,
          command: ConversationCommands.messageSend,
          payload: jsonEncode(<String, Object?>{
            'conversationId': conversationId,
            'body': content.value,
            'clientMessageId': clientMessageId,
          }),
          scopeId: conversationId,
          now: now,
        );

        // The rail has to move immediately too, or the thread the user just
        // wrote in sits below older ones until a server event arrives.
        await _dao.touchWithMessage(
          conversationId: conversationId,
          preview: content.preview(),
          messageAt: now,
        );
      });
    } on Object catch (error, stackTrace) {
      _logger.error(
        'failed to queue outbound message',
        error: error,
        stackTrace: stackTrace,
      );

      throw DatabaseFailure(
        message: 'The message could not be saved.',
        cause: error,
      );
    }

    return message;
  }

  @override
  Future<int> upsertAll(List<Message> messages, {DateTime? eventAt}) async {
    if (messages.isEmpty) return 0;

    try {
      final written = await _dao.upsertMessages(
        messages.map(_toCompanion).toList(growable: false),
        eventAt: eventAt,
      );

      // Keep the rail's preview and ordering in step with the newest message
      // written, so an incoming message reorders the list without a separate
      // conversation event.
      final newest = messages.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );

      await _dao.touchWithMessage(
        conversationId: newest.conversationId,
        preview: _previewOf(newest.body),
        messageAt: newest.createdAt,
      );

      return written;
    } on Object catch (error, stackTrace) {
      _logger.error(
        'failed to write messages',
        error: error,
        stackTrace: stackTrace,
      );

      throw DatabaseFailure(
        message: 'Could not save messages locally.',
        cause: error,
      );
    }
  }

  @override
  Future<void> updateState({
    required String messageId,
    required MessageState state,
    String? externalId,
    String? failureReason,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? eventAt,
  }) async {
    final changes = MessagesCompanion(
      state: Value<MessageStateRow>(_toRowState(state)),
      externalId: Value<String?>(externalId),
      failureReason: Value<String?>(failureReason),
      deliveredAt: Value<DateTime?>(deliveredAt),
      readAt: Value<DateTime?>(readAt),
      updatedAt: Value<DateTime?>(_clock().toUtc()),
    );

    await _dao.updateMessage(
      messageId,
      // Stamped only when the change came from a server event; a local
      // transition must not advance the ordering guard.
      eventAt == null
          ? changes
          : changes.copyWith(lastEventAt: Value<DateTime?>(eventAt)),
    );
  }

  @override
  Future<void> reconcile({
    required String clientMessageId,
    required String serverMessageId,
    required MessageState state,
  }) async {
    // Already re-keyed -- a duplicate acknowledgement, which the idempotency
    // key makes possible and which must be a no-op rather than an error.
    if (clientMessageId == serverMessageId) {
      await updateState(messageId: serverMessageId, state: state);

      return;
    }

    await _dao.rekeyMessage(
      fromId: clientMessageId,
      toId: serverMessageId,
      changes: MessagesCompanion(
        clientMessageId: Value<String?>(clientMessageId),
        state: Value<MessageStateRow>(_toRowState(state)),
        updatedAt: Value<DateTime?>(_clock().toUtc()),
      ),
    );
  }

  @override
 /// Loads the newest page when the screen opens for the first time.
Future<int> loadLatest({
  required String conversationId,
  int limit = 50,
}) async {
  try {
    final page = await _remote.listMessages(
      conversationId: conversationId,
      // قبل "دلوقتي" (أو استخدم API منفصل بترجع آخر N مباشرة)
      before: _clock().toUtc(),
      limit: limit,
    );

    if (page.messages.isEmpty) return 0;

    return await _dao.upsertMessages(
      page.messages.map(_toCompanion).toList(growable: false),
    );
  } on FormatException catch (error) {
    throw UnknownFailure(
      message0: 'The server sent unexpected message history.',
      cause: error,
    );
  } on Object catch (error, stackTrace) {
    _logger.error(
      'failed to load latest messages',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

  @override
  Future<int> loadOlder({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      final page = await _remote.listMessages(
        conversationId: conversationId,
        before: before,
        limit: limit,
      );

      if (page.messages.isEmpty) return 0;

      // Written without an `eventAt` guard: history is older than anything
      // held, so there is no newer state for it to overwrite.
      return await _dao.upsertMessages(
        page.messages.map(_toCompanion).toList(growable: false),
      );
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent unexpected message history.',
        cause: error,
      );
    }
  }

  @override
  Future<void> remove(String messageId) async {
    await _dao.removeMessage(messageId);
    await _outbox.remove(messageId);
  }

  /// A one-line rail preview, or null when there is no text to preview.
  static String? _previewOf(String? body) {
    if (body == null) return null;

    final parsed = MessageContent.parse(body);

    return switch (parsed) {
      ValidMessageContent(:final content) => content.preview(),
      InvalidMessageContent() => null,
    };
  }

  static Message _toEntity(MessageRow row) {
    return Message(
      id: row.id,
      conversationId: row.conversationId,
      clientMessageId: row.clientMessageId,
      direction: row.direction == MessageDirectionRow.inbound
          ? MessageDirection.inbound
          : MessageDirection.outbound,
      state: _toEntityState(row.state),
      type: row.type,
      body: row.body,
      mediaUrl: row.mediaUrl,
      localMediaPath: row.localMediaPath,
      authorName: row.authorName,
      authorId: row.authorId,
      isFromBot: row.isFromBot,
      failureReason: row.failureReason,
      externalId: row.externalId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deliveredAt: row.deliveredAt,
      readAt: row.readAt,
      queuedAt: row.queuedAt,
    );
  }

  static MessagesCompanion _toCompanion(Message message) {
    return MessagesCompanion.insert(
      id: message.id,
      conversationId: message.conversationId,
      clientMessageId: Value<String?>(message.clientMessageId),
      direction: message.direction == MessageDirection.inbound
          ? MessageDirectionRow.inbound
          : MessageDirectionRow.outbound,
      state: _toRowState(message.state),
      type: Value<String>(message.type),
      body: Value<String?>(message.body),
      mediaUrl: Value<String?>(message.mediaUrl),
      localMediaPath: Value<String?>(message.localMediaPath),
      authorName: Value<String?>(message.authorName),
      authorId: Value<String?>(message.authorId),
      isFromBot: Value<bool>(message.isFromBot),
      failureReason: Value<String?>(message.failureReason),
      externalId: Value<String?>(message.externalId),
      createdAt: message.createdAt,
      updatedAt: Value<DateTime?>(message.updatedAt),
      deliveredAt: Value<DateTime?>(message.deliveredAt),
      readAt: Value<DateTime?>(message.readAt),
      queuedAt: Value<DateTime?>(message.queuedAt),
    );
  }

  static MessageStateRow _toRowState(MessageState state) => switch (state) {
    MessageState.pending => MessageStateRow.pending,
    MessageState.sending => MessageStateRow.sending,
    MessageState.failed => MessageStateRow.failed,
    MessageState.sent => MessageStateRow.sent,
    MessageState.delivered => MessageStateRow.delivered,
    MessageState.read => MessageStateRow.read,
    MessageState.discarded => MessageStateRow.discarded,
  };

  static MessageState _toEntityState(MessageStateRow state) => switch (state) {
    MessageStateRow.pending => MessageState.pending,
    MessageStateRow.sending => MessageState.sending,
    MessageStateRow.failed => MessageState.failed,
    MessageStateRow.sent => MessageState.sent,
    MessageStateRow.delivered => MessageState.delivered,
    MessageStateRow.read => MessageState.read,
    MessageStateRow.discarded => MessageState.discarded,
  };
}
