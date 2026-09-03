import '../../../../failures/app_failure.dart';
import '../../domain/entities/user.dart';

/// Where the app is in deciding who the user is.
///
/// [unknown] is a real state, not a placeholder: at launch the app has not yet
/// read its cache, and routing on "not authenticated" during that window would
/// flash the login screen at an already-signed-in user on every cold start.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Application-level authentication state.
///
/// Lives in `application/state/` rather than in a controller because more than
/// one presentation surface depends on it -- the router's guard and the app
/// shell both read it, and neither owns it.
final class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.failure,
  });

  const AuthState.unknown() : this();

  const AuthState.authenticated(Session session)
    : this(status: AuthStatus.authenticated, session: session);

  const AuthState.unauthenticated({AppFailure? failure})
    : this(status: AuthStatus.unauthenticated, failure: failure);

  final AuthStatus status;
  final Session? session;

  /// Why the last session ended, when it ended badly. Null for an ordinary
  /// sign-out.
  final AppFailure? failure;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isResolved => status != AuthStatus.unknown;

  AuthenticatedUser? get user => session?.user;

  Workspace? get workspace => session?.workspace;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.status == status &&
      other.session == session &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(status, session, failure);
}
