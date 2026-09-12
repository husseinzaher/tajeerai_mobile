/// A phone number reduced to what two devices can agree on.
///
/// ## Why this is not a port of the backend's `normalise`
///
/// The API normalises to E.164 with libphonenumber and a default country of
/// Saudi Arabia, and it does that on every write -- so a number typed into
/// this app is stored in the shape the server decided, not the shape the
/// phone guessed. Re-implementing that parse here without the same metadata
/// would produce a second opinion, and the numbers the two would disagree on
/// are exactly the ambiguous ones a caller card has to get right.
///
/// So this mirrors the half that is arithmetic rather than judgement --
/// `PhoneNumber.digits`, character for character -- and leaves the parse to
/// the server. What the client needs locally is not "what is the canonical
/// form of this number" but "is the number now ringing the same person as the
/// number on this row", and that question is answered by comparing digits.
abstract final class PhoneDigits {
  /// A leading `+` and the digits, nothing else.
  ///
  /// Mirrors the backend's `PhoneNumber.digits`, whose regex is
  /// `/(?!^\+)[^\d]/g`: every non-digit goes, except a `+` in first position.
  static String of(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final StringBuffer kept = StringBuffer();

    for (int index = 0; index < trimmed.length; index++) {
      final String character = trimmed[index];

      if (index == 0 && character == '+') {
        kept.write(character);
        continue;
      }

      if (character.codeUnitAt(0) >= 0x30 && character.codeUnitAt(0) <= 0x39) {
        kept.write(character);
      }
    }

    return kept.toString();
  }

  /// The digits alone, without the `+`. The indexed lookup key.
  ///
  /// A row is found by this rather than by the stored spelling, because the
  /// same person reaches the workspace as `+966 50 123 4567` from a contact
  /// card and as `0501234567` from a call log.
  static String bare(String value) {
    final String digits = of(value);

    return digits.startsWith('+') ? digits.substring(1) : digits;
  }

  /// How many trailing digits two numbers must share to be the same person.
  ///
  /// Nine is the length of a Gulf subscriber number without its country code
  /// or trunk prefix, which is the longest suffix every spelling of one number
  /// has in common: `+966501234567`, `00966501234567` and `0501234567` all end
  /// in `501234567`. Shorter would start matching strangers -- seven digits
  /// collide across a city.
  static const int significantSuffix = 9;

  /// The tail two numbers are compared on, or the whole thing when it is
  /// shorter than [significantSuffix] -- a short code is not a subscriber
  /// number and must match exactly.
  static String suffix(String value) {
    final String digits = bare(value);

    return digits.length <= significantSuffix
        ? digits
        : digits.substring(digits.length - significantSuffix);
  }

  /// Whether two numbers, however each was spelled, reach the same person.
  static bool sameNumber(String left, String right) {
    final String a = suffix(left);
    final String b = suffix(right);

    return a.isNotEmpty && a == b;
  }
}
