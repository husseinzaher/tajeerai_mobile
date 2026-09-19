import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// The country a phone identifier is read against when it does not name one.
///
/// Matches the web sign-in field (`frontend/src/app/(auth)/login/page.tsx`).
const String loginPhoneDefaultCountry = 'SA';

/// A phone number the reader understood from what was typed.
final class DialledNumber {
  const DialledNumber({this.country, required this.number});

  /// ISO 3166-1 alpha-2 when known.
  final String? country;

  /// E.164, e.g. `+201008755187`.
  final String number;

  @override
  bool operator ==(Object other) =>
      other is DialledNumber &&
      other.country == country &&
      other.number == number;

  @override
  int get hashCode => Object.hash(country, number);
}

/// Reads login identifiers the way the web sign-in field does.
abstract final class LoginPhoneReader {
  /// Digits, `+`, spaces, dashes and parentheses — not an email.
  static bool isPhoneShaped(String value) =>
      value.isNotEmpty && RegExp(r'^[0-9+\-\s()]+$').hasMatch(value);

  /// What the API should receive: E.164 for a complete phone, otherwise text.
  static String resolveForSubmit(String raw) {
    final String trimmed = raw.trim();

    if (isPhoneShaped(trimmed)) {
      final DialledNumber? phone = readPhoneNumber(trimmed);

      if (phone != null) return phone.number;
    }

    return trimmed;
  }

  /// Reads [raw] as an international number when it carries its own code.
  static DialledNumber? readDialledNumber(
    String raw, {
    String selectedCountry = loginPhoneDefaultCountry,
  }) {
    final String digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return null;

    final bool dialled = digits.startsWith('00');
    final bool stated = raw.trimLeft().startsWith('+') || dialled;
    final List<String> candidates = dialled
        ? <String>[digits.substring(2), digits]
        : <String>[digits];

    DialledNumber? international;

    for (final String candidate in candidates) {
      final DialledNumber? parsed = _parseInternational('+$candidate');

      if (parsed != null) {
        international = parsed;
        break;
      }
    }

    if (international == null) return null;

    if (!stated) {
      final DialledNumber? local = _parseLocal(raw, selectedCountry);

      if (local != null && local.number != international.number) {
        return null;
      }
    }

    return international;
  }

  /// Reads [raw] as a phone number, by its own code or as a local number of
  /// [defaultCountry]. Returns null until the digits are a complete number.
  static DialledNumber? readPhoneNumber(
    String raw, {
    String defaultCountry = loginPhoneDefaultCountry,
  }) {
    final DialledNumber? dialled = readDialledNumber(
      raw,
      selectedCountry: defaultCountry,
    );

    if (dialled != null) return dialled;

    return _parseLocal(raw, defaultCountry);
  }

  static DialledNumber? _parseInternational(String value) {
    try {
      final PhoneNumber parsed = PhoneNumber.parse(value);

      if (!parsed.isValid()) return null;

      return DialledNumber(country: parsed.isoCode.name, number: _e164(parsed));
    } on Object {
      return null;
    }
  }

  static DialledNumber? _parseLocal(String raw, String country) {
    try {
      final IsoCode iso = IsoCode.values.byName(country);
      final PhoneNumber parsed = PhoneNumber.parse(
        raw,
        destinationCountry: iso,
      );

      if (!parsed.isValid()) return null;

      return DialledNumber(country: parsed.isoCode.name, number: _e164(parsed));
    } on Object {
      return null;
    }
  }

  static String _e164(PhoneNumber parsed) =>
      parsed.international.replaceAll(' ', '');
}
