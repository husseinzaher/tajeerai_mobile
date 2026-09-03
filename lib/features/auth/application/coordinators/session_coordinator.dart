import 'dart:async';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/auth_service.dart';
import '../contracts/session_capability.dart';
import '../events/auth_events.dart';
import '../state/auth_state.dart';

/// Orchestrates the session's lifecycle.
///
/// The workflow layer, and the boundary the rest of the app depends on:
///
/// - **domain** (`AuthService`) decides whether credentials are acceptable and
///   what a session means;
/// - **this** sequences the steps around that decision -- restore at start-up,
///   publish the outcome, announce the event, tear everything down on the way
///   out.
///
/// It holds no business rules. `signIn` does not decide what a valid password
/// is; it calls the service that does. Keeping that line sharp is what stops a
/// coordinator becoming the god class the architecture warns about.
///
/// It also implements [SessionCapability], which is how Conversations reads
/// the current user without knowing this class exists.
class SessionCoordinator implements SessionCapability {
  SessionCoordinator({required AuthService authService, required Logger logger})
    : _authService = authService,
      _logger = logger;

  final AuthService _authService;
  final Logger _logger;

  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast();
  final StreamController<AuthEvent> _events =
      StreamController<AuthEvent>.broadcast();

  AuthState _state = const AuthState.unknown();

  AuthState get state => _state;

  Stream<AuthState> get states => _states.stream;

  /// Session facts other features subscribe to.
  Stream<AuthEvent> get events => _events.stream;

  @override
  Session? get currentSession => _state.session;

  @override
  Stream<Session?> get sessionChanges =>
      _states.stream.map((state) => state.session).distinct();

  @override
  String? get currentUserId => _state.session?.user.id;

  @override
  String? get currentWorkspaceId => _state.session?.workspace?.id;

  /// Resolves the session at start-up.
  ///
  /// Always leaves [state] resolved, whatever happens: a start-up that throws
  /// and leaves the status [AuthStatus.unknown] hangs the app on its splash
  /// screen forever, which is worse than showing the login form.
  Future<void> restore() async {
    try {
      final session = await _authService.restore();

      if (session == null) {
        _publish(const AuthState.unauthenticated());

        return;
      }

      _publish(AuthState.authenticated(session));
      _announce(SignedIn(session: session, wasRestored: true));
    } on Object catch (error, stackTrace) {
      _logger.error(
        'session restore failed',
        error: error,
        stackTrace: stackTrace,
      );

      _publish(const AuthState.unauthenticated());
    }
  }

  /// Signs in and publishes the resulting session.
  ///
  /// Rethrows the failure so the controller can render it against the right
  /// form field. The state is left unauthenticated with the failure attached,
  /// which is what the router reads.
  Future<Session> signIn({
    required String identifier,
    required String password,
    bool remember = false,
  }) async {
    try {
      final session = await _authService.signIn(
        identifier: identifier,
        password: password,
        remember: remember,
      );

      _publish(AuthState.authenticated(session));
      _announce(SignedIn(session: session, wasRestored: false));

      return session;
    } on Object catch (error) {
      final failure = asAppFailure(error, 'Could not sign in.');
      _publish(AuthState.unauthenticated(failure: failure));

      throw failure;
    }
  }

  /// Ends the session.
  ///
  /// [expired] marks a sign-out the server forced, so the login screen can
  /// explain why the user is looking at it.
  @override
  Future<void> signOut({bool expired = false}) async {
    try {
      await _authService.signOut();
    } on Object catch (error, stackTrace) {
      // Never blocks. Local state is cleared regardless -- see
      // `AuthRepositoryImpl.signOut`, which does that in a `finally`.
      _logger.error('sign-out failed', error: error, stackTrace: stackTrace);
    }

    _publish(
      AuthState.unauthenticated(
        failure: expired
            ? const AuthenticationFailure(
                message: 'Your session ended. Please sign in again.',
                sessionExpired: true,
              )
            : null,
      ),
    );

    _announce(SignedOut(wasExpired: expired));
  }

  /// Called when the socket reports the credential is no longer accepted and
  /// could not be refreshed.
  Future<void> handleSessionExpired() => signOut(expired: true);

  void _publish(AuthState next) {
    if (_state == next) return;

    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _announce(AuthEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> dispose() async {
    await _states.close();
    await _events.close();
  }
}
