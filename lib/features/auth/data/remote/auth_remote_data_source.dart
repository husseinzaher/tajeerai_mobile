import '../../../../infrastructure/network/http_client.dart';
import '../../../../infrastructure/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../models/session_dto.dart';

/// The auth HTTP endpoints.
///
/// The justification for talking HTTP here is structural: the socket handshake
/// needs a token, and a token is what signing in produces. There is no
/// connection to send credentials over until this has run.
///
/// ## Cookies to tokens
///
/// The backend was built for a browser: `setAuthCookies` writes `tj_access`
/// and `tj_refresh` as httpOnly cookies and the response body carries only
/// `{user, tenant}`. A mobile client cannot read an httpOnly cookie from
/// JavaScript, but it is not a browser -- the HTTP client's cookie jar holds the
/// whole `Set-Cookie`, and the value can be read straight out of it.
///
/// That is what [_captureTokens] does, and it is why this client needs no
/// server change: the socket's `SocketAuthService` already accepts
/// `handshake.auth.token` alongside the cookie.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required HttpClient http,
    required SecureStorage secureStorage,
  }) : _http = http,
       _secureStorage = secureStorage;

  final HttpClient _http;
  final SecureStorage _secureStorage;

  static const String _loginPath = '/v1/auth/login';
  static const String _refreshPath = '/v1/auth/refresh';
  static const String _logoutPath = '/v1/auth/logout';
  static const String _sessionPath = '/v1/auth/session';

  /// The two session cookies, which are also the secure-storage keys they are
  /// kept under between runs.
  static const List<String> _sessionCookies = <String>[
    SecureStorage.accessTokenKey,
    SecureStorage.refreshTokenKey,
  ];

  /// `POST /v1/auth/login`.
  ///
  /// Throws [HttpException]; the repository translates. A 401 here means bad
  /// credentials, not an expired session -- the distinction matters because
  /// only the second should send the user to a "your session ended" message.
  Future<Session> signIn({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    final response = await _http.post(
      _loginPath,
      body: <String, Object?>{
        'identifier': identifier,
        'password': password,
        'remember': remember,
      },
    );

    await _captureTokens();

    return SessionDto.decode(response);
  }

  /// `POST /v1/auth/refresh`, using the refresh cookie held in the jar.
  Future<Session> refresh() async {
    final response = await _http.post(_refreshPath);
    await _captureTokens();

    return SessionDto.decode(response);
  }

  /// `GET /v1/auth/session`.
  Future<Session> currentSession() async {
    final response = await _http.get(_sessionPath);
    await _captureTokens();

    return SessionDto.decode(response);
  }

  /// `POST /v1/auth/logout`. Revokes the refresh token server-side.
  Future<void> signOut() async {
    await _http.post(_logoutPath);
  }

  /// Restores the session cookies from secure storage.
  ///
  /// The jar is in-memory, so a cold start has no cookies and every call would
  /// 401 even though the tokens survived in the Keychain. Seeding it here is
  /// what makes a session outlive the process.
  Future<void> restoreCookies() async {
    final Map<String, String> stored = <String, String>{};

    for (final String name in _sessionCookies) {
      final String? value = await _secureStorage.read(name);
      if (value != null) stored[name] = value;
    }

    await _http.seedCookies(stored);
  }

  /// Mirrors the session cookies into secure storage.
  ///
  /// Two reasons, both necessary: the Keychain is where a credential is
  /// allowed to rest between runs, and the socket handshake needs the access
  /// token's *value*, which only the jar has.
  Future<void> _captureTokens() async {
    final Map<String, String> cookies = await _http.readCookies();

    for (final String name in _sessionCookies) {
      final String? value = cookies[name];
      if (value != null) await _secureStorage.write(name, value);
    }
  }

  /// Clears cookies and stored credentials.
  Future<void> clearTokens() async {
    await _http.clearCookies();
    await _secureStorage.clear();
  }
}
