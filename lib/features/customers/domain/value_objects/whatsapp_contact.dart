/// What WhatsApp knows a contact as, read out of the contact's metadata.
///
/// The web dashboard reads the same two keys (`whatsappUsername`,
/// `whatsappUserId`), written by the WhatsApp channel when a conversation
/// starts. Both are optional: a contact typed in by hand has neither.
final class WhatsAppContact {
  const WhatsAppContact({this.username, this.userId});

  factory WhatsAppContact.fromMetadata(Map<String, Object?> metadata) {
    return WhatsAppContact(
      username: _text(metadata['whatsappUsername']),
      userId: _text(metadata['whatsappUserId']),
    );
  }

  /// Without the `@`; see [handle].
  final String? username;

  /// WhatsApp's own id for the person. Opaque, and only useful to copy.
  final String? userId;

  bool get isEmpty => username == null && userId == null;

  /// `@name`, the way WhatsApp itself writes it.
  String? get handle => username == null ? null : '@$username';

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String value = raw.trim();

    return value.isEmpty ? null : value;
  }
}
