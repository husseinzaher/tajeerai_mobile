/// One thing somebody wrote down about a contact.
///
/// Mirrors the API's `NoteEntry`. Append-only there and read-only here: an
/// entry records what somebody knew at a time, and a record that can be
/// rewritten afterwards is not a record.
final class CustomerNote {
  const CustomerNote({
    required this.id,
    required this.customerId,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.followUpAt,
    this.followUpDoneAt,
  });

  final String id;
  final String customerId;
  final String body;

  /// Null for an entry the system wrote itself, and for one whose author has
  /// since left the workspace -- the row outlives the person who wrote it.
  final String? authorId;

  /// Their name as it stood when they wrote it. Snapshotted by the server, so
  /// the screen never has to resolve a member who may be gone.
  final String? authorName;

  final DateTime createdAt;

  /// When to come back to this, when the writer said so.
  final DateTime? followUpAt;

  /// When somebody did. Set by the server when the follow-up is completed.
  final DateTime? followUpDoneAt;

  /// Still owed: a reminder was set and nobody has closed it.
  bool get isFollowUpDue => followUpAt != null && followUpDoneAt == null;

  /// Owed and already past its time.
  bool isOverdue(DateTime now) => isFollowUpDue && followUpAt!.isBefore(now);
}
