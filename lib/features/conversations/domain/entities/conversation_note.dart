/// One entry of a thread's own record: what the team wrote to itself, what
/// the system recorded happening, and what the assistant summarised.
///
/// Mirrors the API's `ConversationNoteView`. Kept as text where the server
/// uses an enum, for the same reason `Message.type` is: the backend adds
/// kinds without a schema change here, and a client enum would turn each new
/// one into a crash.
final class ConversationNote {
  const ConversationNote({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.createdAt,
    this.reason,
    this.body,
    this.authorId,
    this.authorName,
  });

  final String id;
  final String conversationId;

  /// `note`, `closed`, `reopened`, `summary`, or something newer.
  final String type;

  /// The closing reason on a `closed` entry; null on every other kind.
  final String? reason;
  final String? body;

  /// Null for an entry the system wrote, and for one whose author has left.
  final String? authorId;
  final String? authorName;
  final DateTime createdAt;

  bool get isNote => type == 'note';
  bool get isSummary => type == 'summary';
}
