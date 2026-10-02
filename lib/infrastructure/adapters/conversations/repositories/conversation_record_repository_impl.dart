import 'package:drift/drift.dart';

import '../../../../failures/app_failure.dart';
import '../../../../features/conversations/domain/entities/conversation_note.dart';
import '../../../../features/conversations/domain/repositories/conversation_record_repository.dart';
import '../../../api/http_exception.dart';
import '../../../storage/database/app_database.dart';
import '../local/conversation_note_dao.dart';
import '../remote/conversation_record_remote_data_source.dart';

/// [ConversationRecordRepository] over the local table and the notes endpoints.
class ConversationRecordRepositoryImpl implements ConversationRecordRepository {
  const ConversationRecordRepositoryImpl({
    required ConversationNoteDao dao,
    required ConversationRecordRemoteDataSource remote,
  }) : _dao = dao,
       _remote = remote;

  final ConversationNoteDao _dao;
  final ConversationRecordRemoteDataSource _remote;

  @override
  Stream<List<ConversationNote>> watchNotes(String conversationId) {
    return _dao
        .watchForConversation(conversationId)
        .map(
          (List<ConversationNoteRow> rows) =>
              rows.map(_toNote).toList(growable: false),
        );
  }

  @override
  Future<int> synchronizeNotes(String conversationId) async {
    final List<ConversationNote> notes = await _guard(
      () => _remote.fetchNotes(conversationId),
    );

    await _dao.replaceForConversation(
      conversationId,
      notes.map(_toCompanion).toList(growable: false),
    );

    return notes.length;
  }

  @override
  Future<ConversationNote> addNote(String conversationId, String body) async {
    final ConversationNote note = await _guard(
      () => _remote.addNote(conversationId, body),
    );

    // Written locally at once, so the card appears the moment the server has
    // agreed to it rather than on the next refresh.
    await _dao.insert(_toCompanion(note));

    return note;
  }

  @override
  Future<ConversationNote> summarize(String conversationId) async {
    final ConversationNote summary = await _guard(
      () => _remote.summarize(conversationId),
    );

    await _dao.insert(_toCompanion(summary));

    return summary;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on HttpException catch (error) {
      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected response.',
        cause: error,
      );
    }
  }

  ConversationNote _toNote(ConversationNoteRow row) {
    return ConversationNote(
      id: row.id,
      conversationId: row.conversationId,
      type: row.type,
      reason: row.reason,
      body: row.body,
      authorId: row.authorId,
      authorName: row.authorName,
      createdAt: row.createdAt,
    );
  }

  ConversationNotesCompanion _toCompanion(ConversationNote note) {
    return ConversationNotesCompanion(
      id: Value<String>(note.id),
      conversationId: Value<String>(note.conversationId),
      type: Value<String>(note.type),
      reason: Value<String?>(note.reason),
      body: Value<String?>(note.body),
      authorId: Value<String?>(note.authorId),
      authorName: Value<String?>(note.authorName),
      createdAt: Value<DateTime>(note.createdAt),
    );
  }
}
