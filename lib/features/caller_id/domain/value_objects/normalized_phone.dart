import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// A phone number normalized for lookup and display.
final class NormalizedPhone {
  const NormalizedPhone({
    required this.raw,
    required this.e164,
    required this.digits,
    required this.suffix,
  });

  final String raw;
  final String e164;
  final String digits;
  final String suffix;

  bool get isPrivate =>
      raw.isEmpty ||
      raw == 'unknown' ||
      raw.toLowerCase() == 'restricted' ||
      raw.toLowerCase() == 'private';

  static NormalizedPhone? parse(String input, {IsoCode defaultRegion = IsoCode.SA}) {
    final String trimmed = input.trim();

    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'restricted' ||
        trimmed.toLowerCase() == 'private' ||
        trimmed == '-1') {
      return null;
    }

    try {
      final PhoneNumber parsed = PhoneNumber.parse(trimmed, callerCountry: defaultRegion);
      final String digits = parsed.nsn;
      final String suffix = digits.length >= 9
          ? digits.substring(digits.length - 9)
          : digits;

      return NormalizedPhone(
        raw: trimmed,
        e164: parsed.international,
        digits: digits,
        suffix: suffix,
      );
    } on Object {
      final String digits = trimmed.replaceAll(RegExp(r'\D'), '');

      if (digits.isEmpty) return null;

      final String suffix = digits.length >= 9
          ? digits.substring(digits.length - 9)
          : digits;

      return NormalizedPhone(
        raw: trimmed,
        e164: trimmed,
        digits: digits,
        suffix: suffix,
      );
    }
  }
}
