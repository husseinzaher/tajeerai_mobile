/// A token file the generator refuses to emit from.
///
/// Carries the JSON pointer of the offending node (`color.dark.textMuted`)
/// rather than only a message, because the first question anybody asks of a
/// generator failure is *which token*, and a message that does not answer it
/// sends them scrolling through a 400-line file.
class TokenFormatException implements Exception {
  const TokenFormatException(this.pointer, this.message);

  /// Dotted path to the node, from the document root.
  final String pointer;

  /// What is wrong, and where possible what to do about it.
  final String message;

  @override
  String toString() => '$pointer: $message';
}
