import '../../../../features/conversations/domain/entities/conversation_note.dart';
import '../../../api/http_client.dart';
import '../models/conversation_note_dto.dart';

/// A thread's record, over HTTP.
///
/// HTTP because the socket exposes no commands for the record - ARCHITECTURE.md
/// §11 names it. The three calls are the web inbox's three: read the record,
/// write an internal note, ask the assistant for a summary.
class ConversationRecordRemoteDataSource {
  const ConversationRecordRemoteDataSource(this._http);

  final HttpClient _http;

  Future<List<ConversationNote>> fetchNotes(String conversationId) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/conversations/$conversationId/notes',
    );

    return ConversationNoteDto.decodeList(
      json['data'],
      conversationId: conversationId,
    );
  }

  Future<ConversationNote> addNote(String conversationId, String body) async {
    final Map<String, Object?> json = await _http.post(
      '/v1/conversations/$conversationId/notes',
      body: <String, Object?>{'body': body},
    );

    return ConversationNoteDto.decode(json, conversationId: conversationId);
  }

  /// The assistant's summary lands on the record as a `summary` entry, which
  /// is what comes back.
  Future<ConversationNote> summarize(String conversationId) async {
    final Map<String, Object?> json = await _http.post(
      '/v1/conversations/$conversationId/summary',
      body: const <String, Object?>{},
    );

    return ConversationNoteDto.decode(json, conversationId: conversationId);
  }
}
