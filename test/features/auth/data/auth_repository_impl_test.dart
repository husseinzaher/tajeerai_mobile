import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/config/app_config.dart';
import 'package:tajeerai_mobile/app/config/environment.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/data/local/auth_local_data_source.dart';
import 'package:tajeerai_mobile/features/auth/data/models/session_dto.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:tajeerai_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/login_identifier.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/password.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/network/http_client.dart';
import 'package:tajeerai_mobile/infrastructure/network/http_exception.dart';
import 'package:tajeerai_mobile/infrastructure/storage/secure_storage.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import 'fakes/in_memory_secure_storage.dart';

/// A payload shaped like the backend's `SessionDto`.
Map<String, Object?> _sessionPayload() => <String, Object?>{
  'user': <String, Object?>{
    'id': 'u1',
    'name': 'Ada Lovelace',
    'email': 'ada@demo.test',
    'phone': null,
    'role': 'member',
    'locale': 'ar',
    'avatar': <String, Object?>{'url': 'https://cdn.test/a.png'},
    'isPlatformAdmin': false,
    'permissions': <Object?>['conversation:read'],
    'denied': <Object?>[],
  },
  'tenant': <String, Object?>{
    'id': 't1',
    'name': 'Demo Workspace',
    'slug': 'demo',
    'status': 'active',
    'locale': 'ar',
    'currency': 'SAR',
    'logo': null,
  },
};

/// An [AuthRemoteDataSource] that answers without a network.
///
/// Subclassed for the same reason as the conversation remote: the real class
/// is concrete, and extracting an interface purely to satisfy a test is the
/// premature abstraction the architecture warns against.
class FakeAuthRemote extends AuthRemoteDataSource {
  FakeAuthRemote({required super.http, required super.secureStorage})
    : super(baseUrl: 'http://localhost');

  Map<String, Object?>? nextPayload = _sessionPayload();
  Object? failureToThrow;

  int signInCalls = 0;
  int refreshCalls = 0;
  int sessionCalls = 0;
  int signOutCalls = 0;
  int restoreCookieCalls = 0;
  int clearTokenCalls = 0;

  String? lastIdentifier;
  bool? lastRemember;

  @override
  Future<Session> signIn({
    required String identifier,
    required String password,
    required bool remember,
  }) async {
    signInCalls += 1;
    lastIdentifier = identifier;
    lastRemember = remember;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return SessionDto.decode(nextPayload!);
  }

  @override
  Future<Session> refresh() async {
    refreshCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return SessionDto.decode(nextPayload!);
  }

  @override
  Future<Session> currentSession() async {
    sessionCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return SessionDto.decode(nextPayload!);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;
  }

  @override
  Future<void> restoreCookies() async => restoreCookieCalls += 1;

  @override
  Future<void> clearTokens() async => clearTokenCalls += 1;
}

void main() {
  late AppDatabase database;
  late InMemorySecureStorage storage;
  late FakeAuthRemote remote;
  late AuthLocalDataSource local;
  late AuthRepositoryImpl repository;

  setUp(() {
    database = openTestDatabase();
    storage = InMemorySecureStorage();

    final http = HttpClient.create(
      config: const AppConfig(
        environment: Environment.development,
        apiBaseUrl: 'http://localhost',
        socketUrl: 'http://localhost',
        connectTimeout: Duration(seconds: 1),
        receiveTimeout: Duration(seconds: 1),
        commandTimeout: Duration(seconds: 1),
      ),
      logger: Logger('test', verbose: false),
      userAgent: 'test',
      cookieJar: CookieJar(),
    );

    remote = FakeAuthRemote(http: http, secureStorage: storage);
    local = AuthLocalDataSource(database: database, secureStorage: storage);

    repository = AuthRepositoryImpl(
      remote: remote,
      local: local,
      logger: Logger('test', verbose: false),
      clock: () => testEpoch,
    );
  });

  tearDown(() => database.close());

  group('signIn', () {
    test('returns the session and caches it locally', () async {
      final session = await repository.signIn(
        identifier: (LoginIdentifier.parse(
          'ada@demo.test',
        ) as ValidLoginIdentifier).identifier,
        password: (Password.parse('secret') as ValidPassword).password,
      );

      expect(session.user.name, 'Ada Lovelace');
      expect(session.workspace!.id, 't1');

      // Cached so the next cold start opens into the authenticated shell
      // without waiting for the network.
      expect(await local.readSession(), isNotNull);
    });

    test('maps a 401 to a rejected sign-in, not an expired session', () async {
      remote.failureToThrow = const HttpException(
        message: 'Unauthorized',
        statusCode: 401,
      );

      await expectLater(
        repository.signIn(
          identifier: (LoginIdentifier.parse(
            'ada@demo.test',
          ) as ValidLoginIdentifier).identifier,
          password: (Password.parse('wrong') as ValidPassword).password,
        ),
        throwsA(
          isA<AuthenticationFailure>().having(
            (failure) => failure.sessionExpired,
            'sessionExpired',
            // The user never had a session, so telling them theirs ended is
            // wrong.
            isFalse,
          ),
        ),
      );
    });

    test('maps a connection error to an offline transport failure', () async {
      remote.failureToThrow = const HttpException(
        message: 'No route',
        isConnectionError: true,
      );

      await expectLater(
        repository.signIn(
          identifier: (LoginIdentifier.parse(
            'ada@demo.test',
          ) as ValidLoginIdentifier).identifier,
          password: (Password.parse('secret') as ValidPassword).password,
        ),
        throwsA(
          isA<TransportFailure>().having(
            (failure) => failure.isOffline,
            'isOffline',
            isTrue,
          ),
        ),
      );
    });

    test('never leaks the infrastructure exception type', () async {
      remote.failureToThrow = const HttpException(
        message: 'Boom',
        statusCode: 500,
      );

      await expectLater(
        repository.signIn(
          identifier: (LoginIdentifier.parse(
            'ada@demo.test',
          ) as ValidLoginIdentifier).identifier,
          password: (Password.parse('secret') as ValidPassword).password,
        ),
        throwsA(allOf(isA<AppFailure>(), isNot(isA<HttpException>()))),
      );
    });

    test('maps a malformed response to an unknown failure', () async {
      remote.nextPayload = <String, Object?>{'unexpected': true};

      await expectLater(
        repository.signIn(
          identifier: (LoginIdentifier.parse(
            'ada@demo.test',
          ) as ValidLoginIdentifier).identifier,
          password: (Password.parse('secret') as ValidPassword).password,
        ),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('cachedSession', () {
    test('re-seeds the cookie jar before reading', () async {
      await repository.cachedSession();

      // The jar is in-memory: a cold start has no cookies, so every later call
      // would 401 even though the tokens survived in the Keychain.
      expect(remote.restoreCookieCalls, 1);
    });

    test('returns null when nothing is cached', () async {
      expect(await repository.cachedSession(), isNull);
    });

    test('returns the cached session after a sign-in', () async {
      await repository.signIn(
        identifier: (LoginIdentifier.parse(
          'ada@demo.test',
        ) as ValidLoginIdentifier).identifier,
        password: (Password.parse('secret') as ValidPassword).password,
      );

      final cached = await repository.cachedSession();

      expect(cached!.user.email, 'ada@demo.test');
      expect(cached.user.permissions, contains('conversation:read'));
    });
  });

  group('restoreSession', () {
    test('treats a 401 as "not signed in" rather than an error', () async {
      remote.failureToThrow = const HttpException(
        message: 'Unauthorized',
        statusCode: 401,
      );

      expect(await repository.restoreSession(), isNull);
    });

    test('treats being offline as "no answer", not an error', () async {
      // The caller falls back to the cache; throwing here would block start-up
      // on a plane.
      remote.failureToThrow = const HttpException(
        message: 'No route',
        isConnectionError: true,
      );

      expect(await repository.restoreSession(), isNull);
    });

    test('reports a genuine server error', () async {
      remote.failureToThrow = const HttpException(
        message: 'Boom',
        statusCode: 500,
      );

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<TransportFailure>()),
      );
    });
  });

  group('signOut', () {
    test('clears local state and stored credentials', () async {
      await repository.signIn(
        identifier: (LoginIdentifier.parse(
          'ada@demo.test',
        ) as ValidLoginIdentifier).identifier,
        password: (Password.parse('secret') as ValidPassword).password,
      );

      await repository.signOut();

      expect(await local.readSession(), isNull);
      expect(await storage.read(SecureStorage.accessTokenKey), isNull);
    });

    test('clears local state even when the server call fails', () async {
      await repository.signIn(
        identifier: (LoginIdentifier.parse(
          'ada@demo.test',
        ) as ValidLoginIdentifier).identifier,
        password: (Password.parse('secret') as ValidPassword).password,
      );

      remote.failureToThrow = const HttpException(
        message: 'No route',
        isConnectionError: true,
      );

      await repository.signOut();

      expect(await local.readSession(), isNull);
    });

    test('wipes workspace data so the next user cannot read it', () async {
      await repository.signIn(
        identifier: (LoginIdentifier.parse(
          'ada@demo.test',
        ) as ValidLoginIdentifier).identifier,
        password: (Password.parse('secret') as ValidPassword).password,
      );

      await repository.signOut();

      // Conversations belong to the workspace that was signed in; leaving them
      // for the next user is a data leak, not a cache hit.
      expect(
        await database.conversationDao.watchConversations().first,
        isEmpty,
      );
    });
  });

  group('token access', () {
    test('reads the access token for the socket handshake', () async {
      await storage.write(SecureStorage.accessTokenKey, 'jwt-value');

      expect(await repository.accessToken(), 'jwt-value');
    });

    test('refreshing returns the newly stored token', () async {
      await storage.write(SecureStorage.accessTokenKey, 'jwt-new');

      expect(await repository.refreshAccessToken(), 'jwt-new');
      expect(remote.refreshCalls, 1);
    });

    test(
      'refreshing returns null when the session cannot be renewed',
      () async {
        remote.failureToThrow = const HttpException(
          message: 'Unauthorized',
          statusCode: 401,
        );

        expect(await repository.refreshAccessToken(), isNull);
      },
    );
  });
}
