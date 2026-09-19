import 'package:flutter/services.dart';

/// Keeps the login identifier Latin-only and shaped for email or phone.
///
/// Arabic and other scripts are rejected outright. Allowed characters match
/// what the web sign-in field accepts: letters and digits for email, plus the
/// punctuation phone numbers use.
final class LoginIdentifierInputFormatter extends TextInputFormatter {
  const LoginIdentifierInputFormatter();

  static final RegExp _allowed = RegExp(r'^[a-zA-Z0-9@._+\-\s()]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;

    if (text.isEmpty || _allowed.hasMatch(text)) {
      return newValue;
    }

    return oldValue;
  }
}
