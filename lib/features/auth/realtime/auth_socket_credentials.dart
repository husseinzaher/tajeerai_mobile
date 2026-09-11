import '../../../infrastructure/network/token_refresher.dart';
import '../../../infrastructure/realtime/authentication/socket_credentials.dart';
import '../domain/repositories/auth_repository.dart';

/// Supplies and renews the socket's credential.
///
/// Lives in the auth feature because a session is auth's business, and the
/// realtime infrastructure must stay unaware of how a token is obtained.
/// `SocketManager` depends on the [SocketCredentialsProvider] interface; this is
/// the implementation it is given at composition time.
///
/// Renewal goes through the shared [TokenRefresher] rather than straight to the
/// repository, so a socket reconnect and an HTTP retry arriving together spend
/// the single-use refresh token once. What an outcome *means* -- a refusal
/// ending the session, a renewed session being published -- is decided by the
/// session coordinator the refresher calls.
class AuthSocketCredentials implements SocketCredentialsProvider {
  AuthSocketCredentials({
    required AuthRepository repository,
    required TokenRefresher refresher,
  }) : _repository = repository,
       _refresher = refresher;

  final AuthRepository _repository;
  final TokenRefresher _refresher;

  @override
  Future<String?> currentToken() => _repository.accessToken();

  @override
  Future<RefreshOutcome> refreshToken() => _refresher.refresh();
}
