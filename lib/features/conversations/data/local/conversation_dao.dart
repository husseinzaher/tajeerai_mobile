import 'package:drift/drift.dart';

import '../../../../infrastructure/database/app_database.dart';
import 'conversation_tables.dart';

part 'conversation_dao.g.dart';

/// Row access for conversations and messages.
///
/// Lives in the feature's data layer, not in `infrastructure/database/`,
/// because these tables are the Conversations feature's own. Infrastructure
/// owns the engine and the business-agnostic tables (outbox, sync metadata);
/// a feature owns its schema.
///
/// Storage only -- no business rules. Ordering for display, whether a send is
/// permitted, and what a state transition means all live in the domain
/// services. What this file *does* own is the write semantics that keep
/// realtime safe: upserts guarded by `lastEventAt` so a late broadcast cannot
/// overwrite newer state.
@DriftAccessor(tables: <Type>[Conversations, Messages])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.database);

  /// The rail, as a reactive query.
  ///
  /// Re-emits whenever a write touches either table -- which is how a socket
  /// event ends up on screen with no invalidation call anywhere.
  Stream<List<ConversationRow>> watchConversations({
    bool includeArchived = false,
    String? searchTerm,
    int limit = 50,
  }) {
    final query = select(conversations);

    if (!includeArchived) {
      query.where((row) => row.isArchived.equals(false));
    }

    final term = searchTerm?.trim();

    if (term != null && term.isNotEmpty) {
      final pattern = '%$term%';

      query.where(
        (row) =>
            row.customerName.like(pattern) |
            row.subject.like(pattern) |
            row.lastMessagePreview.like(pattern),
      );
    }

    query
      ..orderBy(<OrderClauseGenerator<$ConversationsTable>>[
        (row) => OrderingTerm.desc(row.isPinned),
        (row) => OrderingTerm.desc(row.lastMessageAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ])
      ..limit(limit);

    return query.watch();
  }

  Stream<ConversationRow?> watchConversation(String id) {
    return (select(
      conversations,
    )..where((row) => row.id.equals(id))).watchSingleOrNull();
  }

  Future<ConversationRow?> findConversation(String id) {
    return (select(
      conversations,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  /// Writes a conversation, refusing to go backwards in time.
  ///
  /// Returns false when [eventAt] predates the row's `lastEventAt` -- the
  /// frame is a late broadcast and the row already holds newer state. The
  /// backend stamps `occurredAt` on every event precisely so a client can make
  /// this check; without it a reconnect's replay clobbers live data.
  Future<bool> upsertConversation(
    ConversationsCompanion entry, {
    DateTime? eventAt,
  }) async {
    final id = entry.id.value;
    final existing = await findConversation(id);

    if (existing != null && eventAt != null) {
      final held = existing.lastEventAt;

      if (held != null && held.isAfter(eventAt)) return false;
    }

    await into(conversations).insertOnConflictUpdate(
      eventAt == null
          ? entry
          : entry.copyWith(lastEventAt: Value<DateTime?>(eventAt)),
    );

    return true;
  }

  /// Sets the unread count from an authoritative server event.
  Future<void> setUnreadCount(String id, int count) {
    return (update(conversations)..where((row) => row.id.equals(id))).write(
      ConversationsCompanion(unreadCount: Value<int>(count)),
    );
  }

  /// Bumps the rail's preview and sort key when a message lands.
  ///
  /// Only ever moves [lastMessageAt] forward: back-filling history must not
  /// reorder the rail to put an old thread on top.
  Future<void> touchWithMessage({
    required String conversationId,
    required String? preview,
    required DateTime messageAt,
  }) async {
    final existing = await findConversation(conversationId);

    if (existing == null) return;

    final held = existing.lastMessageAt;

    if (held != null && held.isAfter(messageAt)) return;

    await (update(
      conversations,
    )..where((row) => row.id.equals(conversationId))).write(
      ConversationsCompanion(
        lastMessagePreview: Value<String?>(preview),
        lastMessageAt: Value<DateTime?>(messageAt),
      ),
    );
  }

  /// A thread's messages, newest first, capped.
  ///
  /// Descending with a limit so the query reads the *newest* page from the
  /// index; the domain service flips it into reading order.
  Stream<List<MessageRow>> watchMessages(
    String conversationId, {
    int limit = 50,
  }) {
    return (select(messages)
          ..where((row) => row.conversationId.equals(conversationId))
          ..orderBy(<OrderClauseGenerator<$MessagesTable>>[
            (row) => OrderingTerm.desc(row.createdAt),
          ])
          ..limit(limit))
        .watch();
  }

  Future<MessageRow?> findMessage(String id) {
    return (select(
      messages,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<MessageRow?> findByClientMessageId(String clientMessageId) {
    return (select(messages)
          ..where((row) => row.clientMessageId.equals(clientMessageId)))
        .getSingleOrNull();
  }

  /// The oldest message held locally, which is the cursor for paging back.
  Future<MessageRow?> oldestMessage(String conversationId) {
    return (select(messages)
          ..where((row) => row.conversationId.equals(conversationId))
          ..orderBy(<OrderClauseGenerator<$MessagesTable>>[
            (row) => OrderingTerm.asc(row.createdAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Writes a message, with the same ordering guard as conversations.
  Future<bool> upsertMessage(
    MessagesCompanion entry, {
    DateTime? eventAt,
  }) async {
    final id = entry.id.value;
    final existing = await findMessage(id);

    if (existing != null && eventAt != null) {
      final held = existing.lastEventAt;

      if (held != null && held.isAfter(eventAt)) return false;
    }

    await into(messages).insertOnConflictUpdate(
      eventAt == null
          ? entry
          : entry.copyWith(lastEventAt: Value<DateTime?>(eventAt)),
    );

    return true;
  }

  /// Writes a page of messages in one transaction.
  ///
  /// Atomic on purpose: a partially-applied page would leave a gap in history
  /// that nothing later goes back to fill.
  Future<int> upsertMessages(
    List<MessagesCompanion> entries, {
    DateTime? eventAt,
  }) async {
    var written = 0;

    await transaction(() async {
      for (final entry in entries) {
        if (await upsertMessage(entry, eventAt: eventAt)) written += 1;
      }
    });

    return written;
  }

  Future<void> updateMessage(String id, MessagesCompanion changes) {
    return (update(messages)..where((row) => row.id.equals(id))).write(changes);
  }

  /// Re-keys an optimistic row to the server's id.
  ///
  /// Delete-then-insert because the id is the primary key. Done in a
  /// transaction so the message is never briefly absent from the thread on
  /// screen.
  Future<void> rekeyMessage({
    required String fromId,
    required String toId,
    required MessagesCompanion changes,
  }) async {
    await transaction(() async {
      final existing = await findMessage(fromId);

      if (existing == null) return;

      await (delete(messages)..where((row) => row.id.equals(fromId))).go();

      await into(messages).insertOnConflictUpdate(
        existing
            .toCompanion(false)
            .copyWith(id: Value<String>(toId))
            .copyWith(
              clientMessageId: changes.clientMessageId,
              state: changes.state,
              externalId: changes.externalId,
              updatedAt: changes.updatedAt,
            ),
      );
    });
  }

  Future<void> removeMessage(String id) {
    return (delete(messages)..where((row) => row.id.equals(id))).go();
  }

  Future<void> clear() async {
    await transaction(() async {
      await delete(messages).go();
      await delete(conversations).go();
    });
  }
}
