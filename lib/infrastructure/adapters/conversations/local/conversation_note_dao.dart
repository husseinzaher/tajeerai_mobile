import 'package:drift/drift.dart';

import '../../../storage/database/app_database.dart';
import 'conversation_tables.dart';

part 'conversation_note_dao.g.dart';

/// Reads and replaces a thread's record.
@DriftAccessor(tables: <Type>[ConversationNotes])
class ConversationNoteDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationNoteDaoMixin {
  ConversationNoteDao(super.database);

  /// Oldest first - the order a thread reads in.
  Stream<List<ConversationNoteRow>> watchForConversation(
    String conversationId,
  ) {
    return (select(conversationNotes)
          ..where(
            ($ConversationNotesTable row) =>
                row.conversationId.equals(conversationId),
          )
          ..orderBy(<OrderClauseGenerator<$ConversationNotesTable>>[
            ($ConversationNotesTable row) => OrderingTerm.asc(row.createdAt),
          ]))
        .watch();
  }

  /// Replaces one thread's record with what the server just returned.
  Future<void> replaceForConversation(
    String conversationId,
    List<ConversationNotesCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(conversationNotes)..where(
            ($ConversationNotesTable row) =>
                row.conversationId.equals(conversationId),
          ))
          .go();

      await batch((Batch batch) => batch.insertAll(conversationNotes, rows));
    });
  }

  Future<void> insert(ConversationNotesCompanion row) {
    return into(conversationNotes)
        .insert(row, mode: InsertMode.insertOrReplace);
  }
}
