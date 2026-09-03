import '../../../../failures/app_failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/login_identifier.dart';
import '../value_objects/password.dart';

/// The business rules of signing in.
///
/// Framework-free by construction: no Flutter, no Riverpod, no Dio, no socket.
/// Everything here is testable with a fake [AuthRepository] and nothing else,
/// which is the point of the layer.
///
/// It owns the rules, not the workflow. "Validate the input, then ask the
/// repository" is a rule; "persist the session, then start the socket, then
/// kick off a first sync" is a workflow and belongs to
/// `application/coordinators/`.
class AuthService {
  const AuthService(this._repository);

  final AuthRepository _repository;

  /// Validates credentials and signs in.
  ///
  /// Client-side validation exists to give an immediate answer, not to
  /// duplicate the server's authority: the same rules run again server-side,
  /// and a rejection there is reported as a [ValidationFailure] all the same.
  Future<Session> signIn({
    required String identifier,
    required String password,
    bool remember = false,
  }) async {
    final credentials = validate(identifier: identifier, password: password);

    return switch (credentials) {
      InvalidCredentials(:final failure) => throw failure,
      ValidCredentials(:final identifier, :final password) =>
        await _repository.signIn(
          identifier: identifier,
          password: password,
          remember: remember,
        ),
    };
  }

  /// Checks the form without contacting anything.
  ///
  /// Exposed separately so a controller can validate on submit without
  /// starting a request, and so the rules are testable in isolation.
  CredentialsValidation validate({
    required String identifier,
    required String password,
  }) {
    final fieldErrors = <String, List<String>>{};

    final parsedIdentifier = LoginIdentifier.parse(identifier);
    final parsedPassword = Password.parse(password);

    if (parsedIdentifier is InvalidLoginIdentifier) {
      fieldErrors['identifier'] = <String>[
        switch (parsedIdentifier.error) {
          LoginIdentifierError.empty => 'identifier.required',
          LoginIdentifierError.tooShort => 'identifier.tooShort',
          LoginIdentifierError.tooLong => 'identifier.tooLong',
        },
      ];
    }

    if (parsedPassword is InvalidPassword) {
      fieldErrors['password'] = <String>[
        switch (parsedPassword.error) {
          PasswordError.empty => 'password.required',
          PasswordError.tooLong => 'password.tooLong',
        },
      ];
    }

    if (fieldErrors.isNotEmpty) {
      return CredentialsValidation.invalid(
        ValidationFailure(
          message: 'Check the details you entered.',
          fieldErrors: fieldErrors,
        ),
      );
    }

    return CredentialsValidation.valid(
      identifier: (parsedIdentifier as ValidLoginIdentifier).identifier,
      password: (parsedPassword as ValidPassword).password,
    );
  }

  /// Restores a session at start-up.
  ///
  /// Local first, then the network. That order is the offline-first rule
  /// applied to authentication: a cached session lets the app open into its
  /// real UI without waiting for -- or requiring -- a reachable server, and
  /// the server refresh that follows only ever *upgrades* what is already
  /// there.
  Future<Session?> restore() async {
    final cached = await _repository.cachedSession();

    if (cached != null) return cached;

    return _repository.restoreSession();
  }

  /// Whether a session may use the workspace features.
  ///
  /// A business rule, and the reason this is not just a null check at the call
  /// site: without a workspace the socket joins no tenant room, so the Inbox
  /// would render an empty list forever rather than telling the user why.
  bool canAccessWorkspace(Session? session) =>
      session != null && session.hasWorkspace;

  Future<void> signOut() => _repository.signOut();
}

/// The outcome of validating a login form.
sealed class CredentialsValidation {
  const CredentialsValidation();

  const factory CredentialsValidation.valid({
    required LoginIdentifier identifier,
    required Password password,
  }) = ValidCredentials;

  const factory CredentialsValidation.invalid(ValidationFailure failure) =
      InvalidCredentials;
}

final class ValidCredentials extends CredentialsValidation {
  const ValidCredentials({required this.identifier, required this.password});

  final LoginIdentifier identifier;
  final Password password;
}

final class InvalidCredentials extends CredentialsValidation {
  const InvalidCredentials(this.failure);

  final ValidationFailure failure;
}
