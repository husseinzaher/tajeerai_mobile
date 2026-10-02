import 'dart:convert';

/// The tags column is a JSON array of strings, encoded and decoded in one
/// place.
///
/// Its own file because both the DAO and the repository need it: the DAO reads
/// tags out of rows for the filter chips, the repository writes them on every
/// upsert, and a second copy of the decode is how the two end up disagreeing
/// about what a malformed column means.
abstract final class CustomerTags {
  static String encode(List<String> tags) => jsonEncode(tags);

  /// Never throws. A column this cannot read is a column written by a version
  /// that is gone, and an empty tag list renders correctly -- a crashed list
  /// screen does not.
  static List<String> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];

    try {
      final Object? decoded = jsonDecode(raw);

      if (decoded is! List<Object?>) return const <String>[];

      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }
}
