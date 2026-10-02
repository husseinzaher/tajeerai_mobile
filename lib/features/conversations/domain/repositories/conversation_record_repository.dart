import '../entities/conversation_note.dart';

/// A thread's own record - notes, log lines, summaries - read locally and
/// refreshed from the server.
///
/// Its own repository rather than more methods on `ConversationRepository`:
/// that one is the socket's, and the record is one of the few things in this
/// app that travels over HTTP (ARCHITECTURE.md §11). Keeping them apart keeps
/// the transport decision visible.
abstract interface class ConversationRecordRepository {
  /// Oldest first, which is the order a thread reads in.
  Stream<List<ConversationNote>> watchNotes(String conversationId);

  /// Fetches the record from the server and replaces the local copy.
  /// Returns how many entries were written.
  Future<int> synchronizeNotes(String conversationId);

  /// Writes an internal note on the thread. Online only: a note is a short
  /// act, and a composer that said "saved" to something still in an outbox
  /// would be telling the team the thread carried words it did not.
  Future<ConversationNote> addNote(String conversationId, String body);

  /// Asks the assistant for a summary, which lands on the record as an entry.
  Future<ConversationNote> summarize(String conversationId);
}
