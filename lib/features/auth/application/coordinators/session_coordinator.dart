import 'dart:async';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/network/token_refresher.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/value_objects/session_renewal.dart';
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
/// the current user without knowing this class exists, and
/// [CredentialRenewer], which is how both transports renew a credential
/// without knowing what a session is.
class SessionCoordinator implements SessionCapability, CredentialRenewer {
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

  /// Takes up a session somebody else produced.
  ///
  /// A social sign-in ends with a session this coordinator did not fetch, and
  /// everything downstream - the shell, the guard, the socket - reacts to the
  /// announcement rather than to the fetch. So the two paths converge here
  /// instead of the app having a second way to become signed in, which is how
  /// one of them ends up forgetting to start the socket.
  void adopt(Session session) {
    _publish(AuthState.authenticated(session));
    _announce(SignedIn(session: session, wasRestored: false));
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

  /// Renews the credential, for either transport.
  ///
  /// The transports reach this through `TokenRefresher`, never directly: the
  /// backend's refresh tokens are single-use, so a socket reconnect and an HTTP
  /// retry have to share one renewal.
  ///
  /// A renewed session is published, so a permission granted or revoked since
  /// sign-in reaches the screens. A refusal ends the session and says why.
  /// Anything else leaves the member signed in.
  @override
  Future<RefreshOutcome> renew() async {
    final SessionRenewal renewal;

    try {
      renewal = await _authService.renew();
    } on Object catch (error, stackTrace) {
      _logger.error(
        'session renewal failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );

      return const RefreshUnavailable();
    }

    switch (renewal) {
      case SessionRenewed(:final session, :final accessToken):
        if (_state.isAuthenticated) {
          _publish(AuthState.authenticated(session));
          _announce(SessionRefreshed(session: session));
        }

        return TokenRefreshed(accessToken);

      case SessionRenewalRejected():
        if (_state.isAuthenticated) await signOut(expired: true);

        return const RefreshRejected();

      case SessionRenewalUnavailable():
        return const RefreshUnavailable();
    }
  }

  Future<void>? _reloading;

  /// Re-reads the session after the server says the member's access changed.
  ///
  /// Concurrent requests share one read. It does nothing while signed out,
  /// and leaves the session as it is when the server cannot be asked.
  Future<void> reloadSession() {
    return _reloading ??= _reload().whenComplete(() => _reloading = null);
  }

  Future<void> _reload() async {
    if (!_state.isAuthenticated) return;

    try {
      final Session? session = await _authService.reload();

      if (session != null && _state.isAuthenticated) {
        _publish(AuthState.authenticated(session));
      }
    } on Object catch (error) {
      _logger.warning(
        'session reload failed',
        data: <String, Object?>{'error': error.runtimeType.toString()},
      );
    }
  }

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
