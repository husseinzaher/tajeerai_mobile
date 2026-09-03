import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/network/http_exception.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/value_objects/login_identifier.dart';
import '../../domain/value_objects/password.dart';
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
  Future<String?> refreshAccessToken() async {
    try {
      await _remote.refresh();

      return await _local.readAccessToken();
    } on HttpException catch (error) {
      _logger.info(
        'session refresh failed',
        data: <String, Object?>{'status': error.statusCode},
      );

      return null;
    } on FormatException {
      return null;
    }
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
