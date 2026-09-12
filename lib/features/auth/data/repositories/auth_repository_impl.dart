import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/network/http_exception.dart';
import '../../domain/entities/social_auth_config.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/login_identifier.dart';
import '../../domain/value_objects/password.dart';
import '../../domain/value_objects/session_renewal.dart';
import '../local/auth_local_data_source.dart';
import '../remote/auth_remote_data_source.dart';

/// The [AuthRepository] implementation.
///
/// This is the translation boundary. Every `HttpException` and
/// `FormatException` is caught here and re-thrown as an `AppFailure`, so the
/// domain service, the coordinator and the controller above it never import
/// an infrastructure type. That is rule 27 of the architecture guard, and it
/// is enforced rather than merely intended.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
  }) : _remote = remote,
       _local = local,
       _logger = logger,
       _clock = clock;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final Logger _logger;
  final DateTime Function() _clock;

  @override
  Future<Session> signIn({
    required LoginIdentifier identifier,
    required Password password,
    bool remember = false,
  }) async {
    try {
      final session = await _remote.signIn(
        identifier: identifier.value,
        password: password.exposeSecret,
        remember: remember,
      );

      await _local.saveSession(session, now: _clock());
      _logger.info('signed in');

      return session;
    } on HttpException catch (error) {
      // A rejected sign-in is not an expired session: the user never had one.
      // Reported as such so the UI says "check your details" rather than
      // "your session ended".
      if (error.statusCode == 401) {
        throw const AuthenticationFailure(
          message: 'Those credentials were not recognised.',
        );
      }

      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected response.',
        cause: error,
      );
    }
  }

  @override
  Future<SocialAuthConfig> socialAuthConfig() async {
    try {
      return await _remote.socialAuthConfig();
    } on HttpException catch (error) {
      // No providers is a legitimate answer and an unreachable server is not
      // worth a message on a sign-in screen: either way there are no buttons.
      _logger.info(
        'social providers unavailable',
        data: <String, Object?>{'status': error.statusCode},
      );

      return const SocialAuthConfig(providers: <String>[]);
    }
  }

  @override
  Uri socialSignInUrl({
    required String provider,
    required String codeChallenge,
    required String locale,
  }) {
    return _remote.socialStartUrl(
      provider: provider,
      codeChallenge: codeChallenge,
      locale: locale,
    );
  }

  @override
  Future<Session> completeSocialSignIn({
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final Session session = await _remote.exchangeSocialCode(
        code: code,
        codeVerifier: codeVerifier,
      );

      await _local.saveSession(session, now: _clock());
      _logger.info('signed in with a provider');

      return session;
    } on HttpException catch (error) {
      throw _socialSignInFailure(error);
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected response.',
        cause: error,
      );
    }
  }

  @override
  Future<Session> completeNativeGoogleSignIn({
    required String idToken,
    required String locale,
  }) async {
    try {
      final Session session = await _remote.exchangeGoogleIdToken(
        idToken: idToken,
        locale: locale,
      );

      await _local.saveSession(session, now: _clock());
      _logger.info('signed in with Google');

      return session;
    } on HttpException catch (error) {
      throw _socialSignInFailure(error);
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected response.',
        cause: error,
      );
    }
  }

  AuthenticationFailure _socialSignInFailure(HttpException error) {
    // The code or token was spent, expired, or refused. Not a session that
    // ended - there was never one. When the server names the reason, pass it
    // through so the screen can localise it.
    if (error.statusCode == 401) {
      return AuthenticationFailure(
        message: error.message,
        sessionExpired: false,
        cause: error,
      );
    }

    throw error.toFailure();
  }

  @override
  Future<Session?> cachedSession() async {
    try {
      // The cookie jar is in-memory, so a cold start has to be re-seeded from
      // the Keychain before any later call can authenticate.
      await _remote.restoreCookies();

      return await _local.readSession();
    } on Object catch (error, stackTrace) {
      // A broken cache must never block sign-in. Reported, then treated as
      // "no session", which sends the user to the login screen.
      _logger.error(
        'could not read cached session',
        error: error,
        stackTrace: stackTrace,
      );

      return null;
    }
  }

  @override
  Future<Session?> restoreSession() async {
    try {
      await _remote.restoreCookies();

      final session = await _remote.currentSession();
      await _local.saveSession(session, now: _clock());

      return session;
    } on HttpException catch (error) {
      // 401 here is the ordinary "not signed in" answer, not a failure worth
      // showing anyone.
      if (error.statusCode == 401) return null;

      // Offline is also not a failure: the caller falls back to the cache.
      if (error.isConnectionError) return null;

      throw error.toFailure();
    } on FormatException {
      return null;
    }
  }

  @override
  Future<SessionRenewal> renewSession() async {
    final Session session;

    try {
      session = await _remote.refresh();
    } on HttpException catch (error) {
      _logger.info(
        'session renewal failed',
        data: <String, Object?>{
          'status': error.statusCode,
          'offline': error.isConnectionError,
        },
      );

      // Only the server refusing the refresh credential ends a session. This
      // used to return null for every failure, and the socket signed members
      // out whenever a refresh happened to meet a dead network.
      return error.statusCode == 401
          ? const SessionRenewalRejected()
          : const SessionRenewalUnavailable();
    } on FormatException {
      return const SessionRenewalUnavailable();
    }

    // Stored before anyone is told: the renewed copy carries the permissions
    // the server grants now, and a cold start has to read those, not the old.
    await _local.saveSession(session, now: _clock());

    final String? token = await _local.readAccessToken();

    // An answer without a credential cannot be used, but it was not a refusal.
    if (token == null) return const SessionRenewalUnavailable();

    return SessionRenewed(session: session, accessToken: token);
  }

  @override
  Future<String?> accessToken() => _local.readAccessToken();

  @override
  Future<void> signOut() async {
    try {
      await _remote.signOut();
    } on HttpException catch (error) {
      // Deliberately swallowed. Signing out offline still has to sign the user
      // out of this device; the server-side refresh token expires on its own.
      _logger.info(
        'remote sign-out failed',
        data: <String, Object?>{'status': error.statusCode},
      );
    } finally {
      await _local.clear();
      await _remote.clearTokens();
    }
  }
}
