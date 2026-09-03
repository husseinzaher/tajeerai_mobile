import '../entities/user.dart';
import '../value_objects/login_identifier.dart';
import '../value_objects/password.dart';

/// Data access for authentication.
///
/// The contract lives in the domain and the implementation in `data/`, so the
/// domain service depends on *what* a session is, never on how it is fetched
/// or stored. Every method throws an `AppFailure` on failure -- the
/// implementation is responsible for translating HTTP and storage exceptions
/// before they cross this boundary.
abstract interface class AuthRepository {
  /// Exchanges credentials for a session.
  ///
  /// [remember] maps to `loginSchema.remember`, which the backend uses to
  /// decide the refresh token's lifetime.
  Future<Session> signIn({
    required LoginIdentifier identifier,
    required Password password,
    bool remember,
  });

  /// The cached session from a previous run, or null.
  ///
  /// Reads local storage only -- never the network. This is what lets the app
  /// open into its authenticated shell offline, which an offline-first client
  /// has to do.
  Future<Session?> cachedSession();

  /// Re-reads the session from the server, refreshing the credential.
  ///
  /// Returns null when no session can be recovered, which is a normal outcome
  /// and not an error: an expired refresh token simply means signing in again.
  Future<Session?> restoreSession();

  /// Rotates the access credential.
  ///
  /// Returns the new access token, or null when the session is unrecoverable.
  /// Used by the socket layer after `auth.expired`.
  Future<String?> refreshAccessToken();

  /// The current access token for the socket handshake, without refreshing.
  Future<String?> accessToken();

  /// Ends the session locally and on the server.
  ///
  /// Local state is cleared even when the server call fails: a user who taps
  /// sign-out on a plane must not stay signed in on the device.
  Future<void> signOut();
}
