import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/config/app_config.dart';
import 'package:TajeerAi/app/config/environment.dart';
import 'package:TajeerAi/features/auth/application/contracts/session_capability.dart';
import 'package:TajeerAi/features/auth/application/coordinators/session_coordinator.dart';
import 'package:TajeerAi/features/auth/domain/repositories/auth_repository.dart';
import 'package:TajeerAi/features/auth/domain/services/auth_service.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/conversation_sync_coordinator.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/outbox_coordinator.dart';
import 'package:TajeerAi/features/conversations/domain/repositories/conversation_repository.dart';
import 'package:TajeerAi/features/conversations/domain/repositories/message_repository.dart';
import 'package:TajeerAi/features/conversations/domain/services/conversation_service.dart';
import 'package:TajeerAi/features/conversations/domain/services/message_service.dart';
import 'package:TajeerAi/features/conversations/realtime/conversation_socket_handler.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/device/platform_info.dart';
import 'package:TajeerAi/infrastructure/logging/crash_reporter.dart';
import 'package:TajeerAi/infrastructure/network/http_client.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_client.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_manager.dart';

import '../../support/test_database.dart';

/// Exercises the composition root.
///
/// The point is not that each class constructs -- their own tests cover that.
/// It is that the *graph* resolves: every provider can be read, every
/// dependency it declares is satisfied, and nothing is wired to the wrong
/// thing. A break here would otherwise only surface when the app boots.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  const config = AppConfig(
    environment: Environment.development,
    apiBaseUrl: 'http://localhost:3000',
    socketUrl: 'http://localhost:3000',
    connectTimeout: Duration(seconds: 1),
    receiveTimeout: Duration(seconds: 1),
    commandTimeout: Duration(seconds: 1),
  );

  const platform = PlatformInfo(
    appVersion: '1.0.0',
    buildNumber: '1',
    operatingSystem: 'test',
  );

  setUp(() {
    database = openTestDatabase();

    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appDatabaseProvider.overrideWithValue(database),
        platformInfoProvider.overrideWithValue(platform),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    database.close();
  });

  group('bootstrap contract', () {
    test('providers bootstrap must supply fail with a named error', () {
      // A missing override has to fail immediately and legibly rather than at
      // the first query. Riverpod wraps the StateError in a ProviderException,
      // so the assertion is on the message reaching the developer.
      final bare = ProviderContainer();

      addTearDown(bare.dispose);

      void expectNamedFailure(String name, Object Function() read) {
        expect(
          read,
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains(
                '$name must be overridden during bootstrap',
              ),
              'names $name',
            ),
          ),
        );
      }

      expectNamedFailure(
        'appConfigProvider',
        () => bare.read(appConfigProvider),
      );
      expectNamedFailure(
        'appDatabaseProvider',
        () => bare.read(appDatabaseProvider),
      );
      expectNamedFailure(
        'platformInfoProvider',
        () => bare.read(platformInfoProvider),
      );
      expectNamedFailure(
        'preferencesStorageProvider',
        () => bare.read(preferencesStorageProvider),
      );
    });
  });

  group('logging', () {
    test('each subsystem gets its own channel', () {
      expect(container.read(appLoggerProvider).channel, 'app');
      expect(container.read(socketLoggerProvider).channel, 'socket');
      expect(container.read(syncLoggerProvider).channel, 'sync');
      expect(container.read(httpLoggerProvider).channel, 'http');
      expect(container.read(databaseLoggerProvider).channel, 'db');
      expect(container.read(authLoggerProvider).channel, 'auth');
    });

    test('verbosity follows the environment', () {
      expect(container.read(appLoggerProvider).verbose, isTrue);

      final production = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: Environment.production,
              apiBaseUrl: 'https://app.tajeerai.net',
              socketUrl: 'https://app.tajeerai.net',
              connectTimeout: Duration(seconds: 1),
              receiveTimeout: Duration(seconds: 1),
              commandTimeout: Duration(seconds: 1),
            ),
          ),
        ],
      );

      addTearDown(production.dispose);

      // Production must not emit the payload-level diagnostics.
      expect(production.read(appLoggerProvider).verbose, isFalse);
    });

    test('a crash reporter is available', () {
      expect(container.read(crashReporterProvider), isA<CrashReporter>());
    });
  });

  group('transports', () {
    test('the HTTP client resolves', () {
      expect(container.read(httpClientProvider), isA<HttpClient>());
    });

    test('the socket client and manager resolve', () {
      expect(container.read(socketClientProvider), isA<SocketClient>());
      expect(container.read(socketManagerProvider), isA<SocketManager>());
    });
  });

  group('auth feature', () {
    test('the whole chain resolves', () {
      expect(container.read(authRepositoryProvider), isA<AuthRepository>());
      expect(container.read(authServiceProvider), isA<AuthService>());
      expect(
        container.read(sessionCoordinatorProvider),
        isA<SessionCoordinator>(),
      );
    });

    test('the session capability is the coordinator', () {
      // Conversations depends on the contract; this is the only place that
      // knows the two are the same object.
      expect(
        container.read(sessionCapabilityProvider),
        same(container.read(sessionCoordinatorProvider)),
      );
      expect(
        container.read(sessionCapabilityProvider),
        isA<SessionCapability>(),
      );
    });

    test('the socket credentials come from the auth feature', () {
      // Infrastructure stays unaware of how a token is obtained.
      expect(container.read(socketCredentialsProvider), isNotNull);
    });
  });

  group('conversations feature', () {
    test('the repositories resolve to their implementations', () {
      expect(
        container.read(conversationRepositoryProvider),
        isA<ConversationRepository>(),
      );
      expect(
        container.read(messageRepositoryProvider),
        isA<MessageRepository>(),
      );
    });

    test('the domain services resolve', () {
      expect(
        container.read(conversationServiceProvider),
        isA<ConversationService>(),
      );
      expect(container.read(messageServiceProvider), isA<MessageService>());
    });

    test('the coordinators resolve', () {
      expect(
        container.read(outboxCoordinatorProvider),
        isA<OutboxCoordinator>(),
      );
      expect(
        container.read(conversationSyncProvider),
        isA<ConversationSyncCoordinator>(),
      );
    });

    test('the realtime handler resolves', () {
      expect(
        container.read(conversationSocketHandlerProvider),
        isA<ConversationSocketHandler>(),
      );
    });

    test('the id generator produces distinct keys', () {
      final generate = container.read(idGeneratorProvider);

      // These are message idempotency keys; a collision would merge two
      // different messages server-side.
      expect(generate(), isNot(generate()));
      expect(generate(), isNotEmpty);
    });
  });

  group('graph identity', () {
    test('providers are singletons within a container', () {
      expect(
        container.read(authRepositoryProvider),
        same(container.read(authRepositoryProvider)),
      );
      expect(
        container.read(socketManagerProvider),
        same(container.read(socketManagerProvider)),
      );
    });

    test('the whole graph resolves without a missing dependency', () {
      // Reading every root provider in one pass: anything unsatisfiable throws
      // here rather than at app boot.
      expect(
        () => <Object?>[
          container.read(secureStorageProvider),
          container.read(fileStorageProvider),
          container.read(connectivityProvider),
          container.read(httpClientProvider),
          container.read(socketManagerProvider),
          container.read(authRepositoryProvider),
          container.read(authServiceProvider),
          container.read(sessionCoordinatorProvider),
          container.read(sessionCapabilityProvider),
          container.read(conversationRepositoryProvider),
          container.read(messageRepositoryProvider),
          container.read(conversationServiceProvider),
          container.read(messageServiceProvider),
          container.read(outboxCoordinatorProvider),
          container.read(conversationSyncProvider),
          container.read(conversationSocketHandlerProvider),
        ],
        returnsNormally,
      );
    });
  });
}
