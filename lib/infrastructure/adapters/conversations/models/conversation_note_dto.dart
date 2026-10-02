import '../../../../features/conversations/domain/entities/conversation_note.dart';

/// Decodes the API's `ConversationNoteView`.
///
/// Forgiving, like every decoder here: an unknown kind stays a string and an
/// unreadable timestamp falls back rather than throws.
abstract final class ConversationNoteDto {
  static ConversationNote decode(
    Map<String, Object?> json, {
    String? conversationId,
  }) {
    final String? id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Record entry carried no id.');
    }

    return ConversationNote(
      id: id,
      conversationId: _text(json['conversationId']) ?? conversationId ?? '',
      type: _text(json['type']) ?? 'note',
      reason: _text(json['reason']),
      body: _text(json['body']),
      authorId: _text(json['authorId']),
      authorName: _text(json['authorName']),
      createdAt: _time(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  /// The endpoint answers with a bare array; `HttpClient` wraps a non-object
  /// body as `{'data': …}`, which is where the caller reads it from.
  static List<ConversationNote> decodeList(
    Object? raw, {
    String? conversationId,
  }) {
    final List<Object?> items = raw is List<Object?> ? raw : const <Object?>[];

    return <ConversationNote>[
      for (final Object? item in items)
        if (_map(item) case final Map<String, Object?> json)
          decode(json, conversationId: conversationId),
    ];
  }

  static DateTime? _time(Object? raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is! String || raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toUtc();
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map<Object?, Object?>) {
      return raw.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    }

    return null;
  }

  static String? _text(Object? raw) {
    final String? value = raw?.toString().trim();

    return value == null || value.isEmpty ? null : value;
  }
}
