import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/app_database.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../local/conversation_dao.dart';
import '../local/conversation_tables.dart';
import '../remote/conversation_remote_data_source.dart';

/// The [ConversationRepository] implementation.
///
/// Reads come from the DAO, writes go to the DAO, and the socket is only ever
/// consulted by the explicit `synchronize*` methods. A screen bound to
/// [watchConversations] cannot cause a network call, because this class gives
/// it no way to.
///
/// It is also the translation boundary: every `SocketException` and drift
/// error is converted to an `AppFailure` here, so nothing above imports an
/// infrastructure exception type.
class ConversationRepositoryImpl implements ConversationRepository {
  ConversationRepositoryImpl({
    required ConversationDao dao,
    required ConversationRemoteDataSource remote,
    required Logger logger,
  }) : _dao = dao,
       _remote = remote,
       _logger = logger;

  final ConversationDao _dao;
  final ConversationRemoteDataSource _remote;
  final Logger _logger;

  @override
  Stream<List<Conversation>> watchConversations({
    bool includeArchived = false,
    String? searchTerm,
    int limit = 50,
  }) {
    return _dao
        .watchConversations(
          includeArchived: includeArchived,
          searchTerm: searchTerm,
          limit: limit,
        )
        .map(
          (rows) => rows.map<Conversation>(_toEntity).toList(growable: false),
        );
  }

  @override
  Stream<Conversation?> watchConversation(String conversationId) {
    return _dao
        .watchConversation(conversationId)
        .map((row) => row == null ? null : _toEntity(row));
  }

  @override
  Future<Conversation?> findConversation(String conversationId) async {
    final row = await _dao.findConversation(conversationId);

    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> synchronizeList({int limit = 25, String? cursor}) async {
    try {
      final page = await _remote.listConversations(
        limit: limit,
        cursor: cursor,
      );
      await upsertAll(page.conversations);

      return page.conversations.length;
    } on FormatException catch (error) {
      // The data source already translates transport failures; what is left
      // to handle here is a reply this client cannot read.
      throw UnknownFailure(
        message0: 'The server sent an unexpected conversation list.',
        cause: error,
      );
    }
  }

  @override
  Future<SyncOutcome> synchronizeSince(
    DateTime since, {
    String? conversationId,
  }) async {
    try {
      final result = await _remote.synchronize(
        since: since,
        conversationId: conversationId,
      );

      await upsertAll(result.conversations);

      return result.toOutcome();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected sync response.',
        cause: error,
      );
    }
  }

  @override
  Future<void> upsertAll(
    List<Conversation> conversations, {
    DateTime? eventAt,
  }) async {
    try {
      for (final conversation in conversations) {
        await _dao.upsertConversation(
          _toCompanion(conversation),
          eventAt: eventAt,
        );
      }
    } on Object catch (error, stackTrace) {
      _logger.error(
        'failed to write conversations',
        error: error,
        stackTrace: stackTrace,
      );

      throw DatabaseFailure(
        message: 'Could not save conversations locally.',
        cause: error,
      );
    }
  }

  /// Clears unread locally, then tells the server.
  ///
  /// Local first so the badge clears the instant the thread opens, even
  /// offline. A failed command leaves the local state optimistic, which the
  /// next sync corrects -- the server is authoritative for unread counts.
  @override
  Future<void> markRead(String conversationId) async {
    await _dao.setUnreadCount(conversationId, 0);

    try {
      await _remote.markRead(conversationId);
    } on AppFailure catch (failure) {
      // Not surfaced: the thread is open in front of the user, and an error
      // toast about a read receipt is noise. The next sync reconciles.
      _logger.debug(
        'read receipt not delivered',
        data: <String, Object?>{'failure': failure.runtimeType.toString()},
      );
    }
  }

  @override
  Future<void> clear() => _dao.clear();

  static Conversation _toEntity(ConversationRow row) {
    return Conversation(
      id: row.id,
      state: switch (row.state) {
        ConversationStateRow.open => ConversationState.open,
        ConversationStateRow.pending => ConversationState.pending,
        ConversationStateRow.closed => ConversationState.closed,
        ConversationStateRow.archived => ConversationState.archived,
      },
      channelId: row.channelId,
      customerId: row.customerId,
      customerName: row.customerName,
      customerAvatarUrl: row.customerAvatarUrl,
      assigneeId: row.assigneeId,
      subject: row.subject,
      unreadCount: row.unreadCount,
      tags: _decodeTags(row.tags),
      lastMessagePreview: row.lastMessagePreview,
      lastMessageAt: row.lastMessageAt,
      lastInboundMessageAt: row.lastInboundMessageAt,
      isPinned: row.isPinned,
      isArchived: row.isArchived,
      isMuted: row.isMuted,
      isBotEnabled: row.isBotEnabled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static ConversationsCompanion _toCompanion(Conversation conversation) {
    return ConversationsCompanion.insert(
      id: conversation.id,
      state: switch (conversation.state) {
        ConversationState.open => ConversationStateRow.open,
        ConversationState.pending => ConversationStateRow.pending,
        ConversationState.closed => ConversationStateRow.closed,
        ConversationState.archived => ConversationStateRow.archived,
      },
      channelId: Value<String?>(conversation.channelId),
      customerId: Value<String?>(conversation.customerId),
      customerName: Value<String?>(conversation.customerName),
      customerAvatarUrl: Value<String?>(conversation.customerAvatarUrl),
      assigneeId: Value<String?>(conversation.assigneeId),
      subject: Value<String?>(conversation.subject),
      unreadCount: Value<int>(conversation.unreadCount),
      isBotEnabled: Value<bool>(conversation.isBotEnabled),
      tags: Value<String>(jsonEncode(conversation.tags)),
      lastMessagePreview: Value<String?>(conversation.lastMessagePreview),
      lastMessageAt: Value<DateTime?>(conversation.lastMessageAt),
      lastInboundMessageAt: Value<DateTime?>(conversation.lastInboundMessageAt),
      isPinned: Value<bool>(conversation.isPinned),
      isArchived: Value<bool>(conversation.isArchived),
      isMuted: Value<bool>(conversation.isMuted),
      createdAt: conversation.createdAt,
      updatedAt: Value<DateTime?>(conversation.updatedAt),
    );
  }

  static List<String> _decodeTags(String raw) {
    if (raw.isEmpty) return const <String>[];

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) return const <String>[];

      return decoded.map((entry) => entry.toString()).toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }
}
