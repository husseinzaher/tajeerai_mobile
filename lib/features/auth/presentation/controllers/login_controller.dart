import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../failures/app_failure.dart';
import '../../application/coordinators/social_sign_in_coordinator.dart';

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
/// Which providers the sign-in screen draws buttons for.
///
/// Asked of the server rather than assumed: a deployment with no client secret
/// filled in offers none, and a button that leads to a 404 is worse than no
/// button.
final FutureProvider<List<String>> socialProvidersProvider =
    FutureProvider<List<String>>(
      (Ref ref) => ref.watch(socialSignInProvider).availableProviders(),
    );

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
      final AppStrings strings = ref.read(appStringsProvider);

      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _messageFor(failure, strings),
        fieldErrors: failure is ValidationFailure
            ? _localise(failure.fieldErrors, strings)
            : const <String, List<String>>{},
      );

      return false;
    }
  }

  /// Signs in with a provider.
  ///
  /// The round trip leaves the app for a Custom Tab and comes back through the
  /// callback URL; the session it produces is handed to the same coordinator a
  /// password sign-in goes through, so the shell, the guard and the socket all
  /// start the way they always do.
  Future<bool> signInWith(String provider) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, clearErrors: true);

    final AppStrings strings = ref.read(appStringsProvider);

    try {
      final SocialSignInOutcome outcome = await ref
          .read(socialSignInProvider)
          .signIn(provider: provider, locale: ref.read(localeProvider).code);

      switch (outcome) {
        case SocialSignedIn(:final session):
          ref.read(sessionCoordinatorProvider).adopt(session);
          state = state.copyWith(isSubmitting: false);

          return true;

        case SocialSignInCancelled():
          // Nothing went wrong. Somebody closed the browser, and a red message
          // for that would be the app telling them off for changing their mind.
          state = state.copyWith(isSubmitting: false);

          return false;

        case SocialSignInRefused(:final reason):
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: strings.socialRefusal(reason),
          );

          return false;
      }
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _messageFor(failure, strings),
      );

      return false;
    }
  }

  /// Turns a failure into something a person can act on.
  ///
  /// Infrastructure detail never reaches the screen: the user is told what to
  /// do, not which layer failed.
  static String _messageFor(AppFailure failure, AppStrings strings) {
    return switch (failure) {
      AuthenticationFailure() => strings.authNotRecognised,
      ValidationFailure() => strings.authCheckDetails,
      TransportFailure(isOffline: true) => strings.authOffline,
      TransportFailure() => strings.authUnreachable,
      AuthorizationFailure() => strings.authForbidden,
      _ => strings.authGeneric,
    };
  }

  /// Maps the domain's error keys to display copy, in the reader's language.
  ///
  /// The domain emits stable keys (`identifier.tooShort`) rather than English,
  /// so the rules stay free of presentation. This used to map them straight to
  /// English strings in an Arabic-first app, and the translation table the
  /// comment here promised could slot in has now slotted in.
  ///
  /// An unknown key still renders as itself rather than as a blank: a raw key
  /// under a field is a bug report, an empty space is a mystery.
  static Map<String, List<String>> _localise(
    Map<String, List<String>> fieldErrors,
    AppStrings strings,
  ) {
    const Map<String, String> copyKeys = <String, String>{
      'identifier.required': 'identifierRequired',
      'identifier.tooShort': 'identifierTooShort',
      'identifier.tooLong': 'identifierTooLong',
      'password.required': 'passwordRequired',
      'password.tooLong': 'passwordTooLong',
    };

    return fieldErrors.map(
      (field, keys) => MapEntry(
        field,
        keys
            .map((key) => strings(copyKeys[key] ?? key))
            .toList(growable: false),
      ),
    );
  }
}
