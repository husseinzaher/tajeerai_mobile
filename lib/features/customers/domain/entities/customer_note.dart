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
}
