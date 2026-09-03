import '../../../infrastructure/logging/logger.dart';
import '../../../infrastructure/realtime/authentication/socket_credentials.dart';
import '../application/coordinators/session_coordinator.dart';
import '../domain/repositories/auth_repository.dart';

/// Supplies and renews the socket's credential.
///
/// Lives in the auth feature because refreshing a session is auth's business,
/// and the realtime infrastructure must stay unaware of how a token is
/// obtained. `SocketManager` depends on the [SocketCredentialsProvider]
/// interface; this is the implementation it is given at composition time.
///
/// It is what makes the socket reconnect-aware: when the server sends
/// `auth.expired` and closes the connection, the manager asks this to renew
/// rather than reconnecting with the credential that was just rejected.
class AuthSocketCredentials implements SocketCredentialsProvider {
  AuthSocketCredentials({
    required AuthRepository repository,
    required SessionCoordinator coordinator,
    required Logger logger,
  }) : _repository = repository,
       _coordinator = coordinator,
       _logger = logger;

  final AuthRepository _repository;
  final SessionCoordinator _coordinator;
  final Logger _logger;

  @override
  Future<String?> currentToken() => _repository.accessToken();

  /// Renews the session, or ends it.
  ///
  /// Returning null tells the manager to stop retrying -- which is the whole
  /// point. Without a terminal answer the client would reconnect forever
  /// against a credential the server has already refused, which is exactly
  /// what the backend's `auth.expired` event exists to prevent.
  ///
  /// Signing out here rather than leaving the app in limbo means the user sees
  /// the login screen instead of an Inbox that silently stopped updating.
  @override
  Future<String?> refreshToken() async {
    final token = await _repository.refreshAccessToken();

    if (token != null) {
      _logger.info('socket credential renewed');

      return token;
    }

    _logger.info('socket credential could not be renewed; ending session');
    await _coordinator.handleSessionExpired();

    return null;
  }
}
