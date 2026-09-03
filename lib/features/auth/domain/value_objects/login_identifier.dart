/// What the user typed into the identifier field.
///
/// The backend accepts an email address *or* a phone number on one field --
/// `loginSchema.identifier`, which `LoginUseCase` tells apart server-side. The
/// client therefore validates shape, not kind: rejecting something that looks
/// like neither would block a login form the server would have accepted.
///
/// A value object rather than a raw `String` so "has this been validated" is
/// visible in the type, and the rule lives in one place instead of being
/// re-implemented in the controller and again in the service.
extension type const LoginIdentifier._(String value) {
  /// The backend's own bounds: `z.string().trim().min(3).max(160)`.
  static const int minLength = 3;
  static const int maxLength = 160;

  /// Validates and normalises, or returns null with the reason.
  ///
  /// Returns a result rather than throwing: an invalid identifier is the
  /// expected outcome of a half-typed form, not an exceptional condition.
  static LoginIdentifierResult parse(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return const LoginIdentifierResult.invalid(LoginIdentifierError.empty);
    }

    if (trimmed.length < minLength) {
      return const LoginIdentifierResult.invalid(LoginIdentifierError.tooShort);
    }

    if (trimmed.length > maxLength) {
      return const LoginIdentifierResult.invalid(LoginIdentifierError.tooLong);
    }

    return LoginIdentifierResult.valid(LoginIdentifier._(trimmed));
  }

  /// Whether this reads as an email address.
  ///
  /// Presentation-only -- it picks the keyboard type. The server decides what
  /// the identifier actually is.
  bool get looksLikeEmail => value.contains('@');
}

/// Why an identifier was rejected. An enum rather than a message so the
/// domain carries no copy -- presentation maps these to localised text.
enum LoginIdentifierError { empty, tooShort, tooLong }

/// The outcome of parsing an identifier.
sealed class LoginIdentifierResult {
  const LoginIdentifierResult();

  const factory LoginIdentifierResult.valid(LoginIdentifier identifier) =
      ValidLoginIdentifier;

  const factory LoginIdentifierResult.invalid(LoginIdentifierError error) =
      InvalidLoginIdentifier;
}

final class ValidLoginIdentifier extends LoginIdentifierResult {
  const ValidLoginIdentifier(this.identifier);

  final LoginIdentifier identifier;
}

final class InvalidLoginIdentifier extends LoginIdentifierResult {
  const InvalidLoginIdentifier(this.error);

  final LoginIdentifierError error;
}
