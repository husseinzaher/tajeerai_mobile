import 'package:cookie_jar/cookie_jar.dart';

import '../../../../infrastructure/network/http_client.dart';
import '../../../../infrastructure/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../models/session_dto.dart';

/// The auth HTTP endpoints.
///
/// **The only feature in the app that talks HTTP for business data**, and the
/// justification is structural: the socket handshake needs a token, and a
/// token is what signing in produces. There is no connection to send
/// credentials over until this has run.
///
/// ## Cookies to tokens
///
/// The backend was built for a browser: `setAuthCookies` writes `tj_access`
/// and `tj_refresh` as httpOnly cookies and the response body carries only
/// `{user, tenant}`. A mobile client cannot read an httpOnly cookie from
/// JavaScript, but it is not a browser -- Dio's cookie jar holds the whole
/// `Set-Cookie`, and the value can be read straight out of it.
///
/// That is what [_captureTokens] does, and it is why this client needs no
/// server change: the socket's `SocketAuthService` already accepts
/// `handshake.auth.token` alongside the cookie.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required HttpClient http,
    required SecureStorage secureStorage,
    required String baseUrl,
  }) : _http = http,
       _secureStorage = secureStorage,
       _baseUri = Uri.parse(baseUrl);

  final HttpClient _http;
  final SecureStorage _secureStorage;
  final Uri _baseUri;

  static const String _loginPath = '/v1/auth/login';
  static const String _refreshPath = '/v1/auth/refresh';
  static const String _logoutPath = '/v1/auth/logout';
  static const String _sessionPath = '/v1/auth/session';

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

  /// Restores the cookie jar from secure storage.
  ///
  /// The jar is in-memory, so a cold start has no cookies and every call would
  /// 401 even though the tokens survived in the Keychain. Seeding it here is
  /// what makes a session outlive the process.
  Future<void> restoreCookies() async {
    final access = await _secureStorage.read(SecureStorage.accessTokenKey);
    final refresh = await _secureStorage.read(SecureStorage.refreshTokenKey);

    final cookies = <Cookie>[
      if (access != null) Cookie(SecureStorage.accessTokenKey, access),
      if (refresh != null) Cookie(SecureStorage.refreshTokenKey, refresh),
    ];

    if (cookies.isEmpty) return;

    for (final cookie in cookies) {
      cookie.path = '/';
    }

    await _http.cookieJar.saveFromResponse(_baseUri, cookies);
  }

  /// Mirrors the session cookies into secure storage.
  ///
  /// Two reasons, both necessary: the Keychain is where a credential is
  /// allowed to rest between runs, and the socket handshake needs the access
  /// token's *value*, which only the jar has.
  Future<void> _captureTokens() async {
    final cookies = await _http.cookieJar.loadForRequest(_baseUri);

    for (final cookie in cookies) {
      switch (cookie.name) {
        case SecureStorage.accessTokenKey:
          await _secureStorage.write(
            SecureStorage.accessTokenKey,
            cookie.value,
          );
        case SecureStorage.refreshTokenKey:
          await _secureStorage.write(
            SecureStorage.refreshTokenKey,
            cookie.value,
          );
      }
    }
  }

  /// Clears cookies and stored credentials.
  Future<void> clearTokens() async {
    await _http.cookieJar.deleteAll();
    await _secureStorage.clear();
  }
}
