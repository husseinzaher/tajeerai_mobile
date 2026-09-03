/// A password as entered.
///
/// Wrapped so it cannot be logged or serialised by accident: [toString] hides
/// the value, which is what stops a password reaching a crash report through
/// an interpolated debug string.
///
/// The client checks only presence and length. Strength rules belong to
/// registration, and the backend's `loginSchema` deliberately requires only
/// `min(1).max(128)` on sign-in -- an existing account whose password predates
/// a rule change must still be able to get in.
final class Password {
  const Password._(this._value);

  /// `z.string().min(1).max(128)`.
  static const int minLength = 1;
  static const int maxLength = 128;

  final String _value;

  /// The raw value. Named so every use site is greppable, and so reading it
  /// looks deliberate rather than incidental.
  String get exposeSecret => _value;

  static PasswordResult parse(String raw) {
    // Deliberately not trimmed: a leading or trailing space is part of a
    // password, and silently stripping it locks the user out of their account.
    if (raw.length < minLength) {
      return const PasswordResult.invalid(PasswordError.empty);
    }

    if (raw.length > maxLength) {
      return const PasswordResult.invalid(PasswordError.tooLong);
    }

    return PasswordResult.valid(Password._(raw));
  }

  /// Never reveals the secret, however it is interpolated.
  @override
  String toString() => 'Password(***)';
}

enum PasswordError { empty, tooLong }

sealed class PasswordResult {
  const PasswordResult();

  const factory PasswordResult.valid(Password password) = ValidPassword;

  const factory PasswordResult.invalid(PasswordError error) = InvalidPassword;
}

final class ValidPassword extends PasswordResult {
  const ValidPassword(this.password);

  final Password password;
}

final class InvalidPassword extends PasswordResult {
  const InvalidPassword(this.error);

  final PasswordError error;
}
