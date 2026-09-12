import '../value_objects/phone_digits.dart';

/// Somebody the workspace sells to.
///
/// The domain's own shape -- not a database row and not an API payload. Both
/// are translated into this at the data boundary.
///
/// `notes` here is the standing description of the person, the field the web
/// dashboard edits in place. What anyone wrote down about them on a given day
/// is a [CustomerNote], and the two are different facts: one is what the
/// workspace believes about somebody, the other is what happened.
final class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    this.email,
    this.phone,
    this.locale = 'ar',
    this.tags = const <String>[],
    this.notes,
    this.typeId,
    this.typeName,
    this.source,
    this.photoUrl,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String locale;
  final List<String> tags;

  /// The standing description. See the class comment.
  final String? notes;

  final String? typeId;
  final String? typeName;

  /// How this contact reached the workspace -- `manual`, `whatsapp_cloud`,
  /// `salla` and the rest. Kept as the server's string rather than an enum:
  /// the backend adds values to `CustomerSource` without a schema change, and
  /// a client enum would turn each new one into a crash.
  final String? source;

  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// What a list row and a caller card show. Never stored -- an empty name is
  /// an empty name, and writing a placeholder into the column would make it
  /// somebody's actual name the next time the row is saved.
  String get displayName {
    final String trimmed = name.trim();

    return trimmed.isEmpty ? (phone?.trim() ?? '') : trimmed;
  }

  /// The two letters a placeholder avatar draws.
  String get initials {
    final List<String> words = displayName
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '';
    if (words.length == 1) {
      final String word = words.first;

      return word.characters(2);
    }

    return '${words.first.characters(1)}${words[1].characters(1)}';
  }

  /// Whether this contact is the person behind [number], however either was
  /// spelled. The caller card's question.
  bool answersTo(String number) {
    final String? own = phone;

    return own != null && PhoneDigits.sameNumber(own, number);
  }
}

extension on String {
  /// The first [count] characters, upper-cased, without splitting a grapheme
  /// in half -- Arabic names are the common case here.
  String characters(int count) {
    final Iterable<int> runes = this.runes.take(count);

    return String.fromCharCodes(runes).toUpperCase();
  }
}
