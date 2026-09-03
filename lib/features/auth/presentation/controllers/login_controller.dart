import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';

/// The login form's state.
///
/// Immutable, and it holds no password: the field's text lives in its
/// [TextEditingController] and is passed to [LoginController.submit] as an
/// argument. Keeping the secret out of an object that gets copied, compared
/// and potentially logged is deliberate.
final class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.errorMessage,
    this.fieldErrors = const <String, List<String>>{},
    this.remember = false,
  });

  final bool isSubmitting;

  /// A form-level message, shown above the fields.
  final String? errorMessage;

  /// Field-level messages, keyed the way the backend keys them.
  final Map<String, List<String>> fieldErrors;

  final bool remember;

  String? errorFor(String field) {
    final errors = fieldErrors[field];

    return errors == null || errors.isEmpty ? null : errors.first;
  }

  bool get hasError => errorMessage != null || fieldErrors.isNotEmpty;

  LoginState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    Map<String, List<String>>? fieldErrors,
    bool? remember,
    bool clearErrors = false,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: clearErrors
          ? const <String, List<String>>{}
          : (fieldErrors ?? this.fieldErrors),
      remember: remember ?? this.remember,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoginState &&
      other.isSubmitting == isSubmitting &&
      other.errorMessage == errorMessage &&
      other.remember == remember &&
      _sameErrors(other.fieldErrors, fieldErrors);

  @override
  int get hashCode =>
      Object.hash(isSubmitting, errorMessage, remember, fieldErrors.length);

  static bool _sameErrors(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;

    for (final entry in a.entries) {
      final other = b[entry.key];

      if (other == null || other.length != entry.value.length) return false;

      for (var i = 0; i < other.length; i++) {
        if (other[i] != entry.value[i]) return false;
      }
    }

    return true;
  }
}

final NotifierProvider<LoginController, LoginState> loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);

/// Owns the login screen's state and actions.
///
/// It validates nothing itself. `AuthService` decides what a valid identifier
/// is, and this maps the resulting failure onto the form -- which is the line
/// between a controller and a business rule.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void setRemember({required bool remember}) {
    state = state.copyWith(remember: remember);
  }

  /// Clears errors as the user edits.
  ///
  /// Leaving a stale "wrong password" under a field the user is actively
  /// fixing reads as the app not noticing them typing.
  void clearErrors() {
    if (!state.hasError) return;

    state = state.copyWith(clearErrors: true);
  }

  /// Attempts a sign-in.
  ///
  /// Returns true on success. The router moves the user on its own -- this
  /// deliberately does not navigate, because navigation belongs to the guard
  /// that watches auth state, not to a form.
  Future<bool> submit({
    required String identifier,
    required String password,
  }) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    try {
      await ref
          .read(sessionCoordinatorProvider)
          .signIn(
            identifier: identifier,
            password: password,
            remember: state.remember,
          );

      state = state.copyWith(isSubmitting: false);

      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _messageFor(failure),
        fieldErrors: failure is ValidationFailure
            ? _localise(failure.fieldErrors)
            : const <String, List<String>>{},
      );

      return false;
    }
  }

  /// Turns a failure into something a person can act on.
  ///
  /// Infrastructure detail never reaches the screen: the user is told what to
  /// do, not which layer failed.
  static String _messageFor(AppFailure failure) {
    return switch (failure) {
      AuthenticationFailure() =>
        'Those details were not recognised. Check them and try again.',
      ValidationFailure() => 'Check the details you entered.',
      TransportFailure(isOffline: true) =>
        'No connection. Check your network and try again.',
      TransportFailure() => 'The server could not be reached. Try again.',
      AuthorizationFailure() => 'This account cannot sign in here.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  /// Maps the domain's error keys to display copy.
  ///
  /// The domain emits stable keys (`identifier.tooShort`) rather than English,
  /// so the rules stay free of presentation and a translation table can slot
  /// in here without touching a service.
  static Map<String, List<String>> _localise(
    Map<String, List<String>> fieldErrors,
  ) {
    const copy = <String, String>{
      'identifier.required': 'Enter your email or phone number.',
      'identifier.tooShort':
          'That is too short to be an email or phone number.',
      'identifier.tooLong': 'That is too long.',
      'password.required': 'Enter your password.',
      'password.tooLong': 'That password is too long.',
    };

    return fieldErrors.map(
      (field, keys) => MapEntry(
        field,
        keys.map((key) => copy[key] ?? key).toList(growable: false),
      ),
    );
  }
}
