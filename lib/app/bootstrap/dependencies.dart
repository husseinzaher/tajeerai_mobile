import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/application/contracts/session_capability.dart';
import '../../features/auth/application/coordinators/session_coordinator.dart';
import '../../features/auth/data/local/auth_local_data_source.dart';
import '../../features/auth/data/remote/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/services/auth_service.dart';
import '../../features/auth/realtime/auth_socket_credentials.dart';
import '../../features/conversations/application/coordinators/conversation_sync_coordinator.dart';
import '../../features/conversations/application/coordinators/outbox_coordinator.dart';
import '../../features/conversations/data/remote/conversation_remote_data_source.dart';
import '../../features/conversations/data/repositories/conversation_repository_impl.dart';
import '../../features/conversations/data/repositories/message_repository_impl.dart';
import '../../features/conversations/domain/repositories/conversation_repository.dart';
import '../../features/conversations/domain/repositories/message_repository.dart';
import '../../features/conversations/domain/services/conversation_service.dart';
import '../../features/conversations/domain/services/message_service.dart';
import '../../features/conversations/realtime/conversation_socket_handler.dart';
import '../../features/customers/application/contracts/customer_directory_capability.dart';
import '../../features/customers/application/coordinators/customer_directory_coordinator.dart';
import '../../features/customers/application/coordinators/customer_sync_coordinator.dart';
import '../../features/customers/data/remote/customer_remote_data_source.dart';
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../infrastructure/database/app_database.dart';
import '../../infrastructure/device/connectivity/connectivity_monitor.dart';
import '../../infrastructure/device/platform_info.dart';
import '../../infrastructure/logging/crash_reporter.dart';
import '../../infrastructure/logging/logger.dart';
import '../../infrastructure/network/http_client.dart';
import '../../infrastructure/network/token_refresher.dart';
import '../../infrastructure/realtime/socket_client.dart';
import '../../infrastructure/realtime/socket_connection.dart';
import '../../infrastructure/realtime/socket_manager.dart';
import '../../infrastructure/storage/file_storage.dart';
import '../../infrastructure/storage/preferences_storage.dart';
import '../../infrastructure/storage/secure_storage.dart';
import '../config/app_config.dart';

/// The application's dependency graph.
///
/// **Everything is composed here, once.** No widget builds a repository, opens
/// a database, or constructs a socket -- they read a provider, and this file
/// decides what is behind it. That is what makes a widget test able to swap
/// the whole data layer for fakes with a handful of overrides.
///
/// Three providers have no default and *must* be overridden in
/// [ProviderScope.overrides] at start-up, because they need async
/// initialisation that a synchronous provider cannot do:
/// [appConfigProvider], [appDatabaseProvider] and [platformInfoProvider].
/// Each throws a named error rather than returning a silent default, so a
/// missing override fails immediately and legibly instead of at the first
/// query.

// ---------------------------------------------------------------------------
// Configuration and platform -- supplied by bootstrap.
// ---------------------------------------------------------------------------

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError(
    'appConfigProvider must be overridden during bootstrap.',
  ),
);

final Provider<PlatformInfo> platformInfoProvider = Provider<PlatformInfo>(
  (ref) => throw StateError(
    'platformInfoProvider must be overridden during bootstrap.',
  ),
);

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError(
    'appDatabaseProvider must be overridden during bootstrap.',
  ),
);

final Provider<PreferencesStorage> preferencesStorageProvider =
    Provider<PreferencesStorage>(
      (ref) => throw StateError(
        'preferencesStorageProvider must be overridden during bootstrap.',
      ),
    );

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

/// A logger per subsystem, so diagnostics stay filterable by channel.
///
/// Verbosity comes from the environment, so debug-level records -- which carry
/// socket and sync detail -- are compiled out of a production run rather than
/// being written and then ignored.
Provider<Logger> _logger(String channel) {
  return Provider<Logger>(
    (ref) => Logger(
      channel,
      verbose: ref.watch(appConfigProvider).environment.verboseDiagnostics,
    ),
  );
}

final Provider<Logger> appLoggerProvider = _logger('app');
final Provider<Logger> httpLoggerProvider = _logger('http');
final Provider<Logger> socketLoggerProvider = _logger('socket');
final Provider<Logger> syncLoggerProvider = _logger('sync');
final Provider<Logger> databaseLoggerProvider = _logger('db');
final Provider<Logger> authLoggerProvider = _logger('auth');

final Provider<CrashReporter> crashReporterProvider = Provider<CrashReporter>(
  (ref) => LoggingCrashReporter(ref.watch(appLoggerProvider)),
);

// ---------------------------------------------------------------------------
// Storage and device
// ---------------------------------------------------------------------------

final Provider<SecureStorage> secureStorageProvider = Provider<SecureStorage>(
  (ref) => SecureStorage(),
);

final Provider<FileStorage> fileStorageProvider = Provider<FileStorage>(
  (ref) => const FileStorage(),
);

final Provider<ConnectivityMonitor> connectivityProvider =
    Provider<ConnectivityMonitor>((ref) => ConnectivityMonitor());

// ---------------------------------------------------------------------------
// Transports
// ---------------------------------------------------------------------------

final Provider<HttpClient> httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient.create(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(httpLoggerProvider),
    userAgent: ref.watch(platformInfoProvider).userAgent,
    // Read when a request needs them, not when the client is built: the
    // session coordinator behind both is itself built on this client.
    renewCredential: () => ref.read(tokenRefresherProvider).refresh(),
    onForbidden: () =>
        unawaited(ref.read(sessionCoordinatorProvider).reloadSession()),
  );
});

final Provider<SocketClient> socketClientProvider = Provider<SocketClient>((
  ref,
) {
  final config = ref.watch(appConfigProvider);

  final client = SocketConnection(
    url: config.socketUrl,
    logger: ref.watch(socketLoggerProvider),
    commandTimeout: config.commandTimeout,
  );

  ref.onDispose(client.dispose);

  return client;
});

final Provider<SocketManager> socketManagerProvider = Provider<SocketManager>((
  ref,
) {
  final manager = SocketManager(
    client: ref.watch(socketClientProvider),
    credentials: ref.watch(socketCredentialsProvider),
    logger: ref.watch(socketLoggerProvider),
    connectivity: ref.watch(connectivityProvider),
  );

  ref.onDispose(manager.dispose);

  return manager;
});

// ---------------------------------------------------------------------------
// Auth feature
// ---------------------------------------------------------------------------

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
      return AuthRemoteDataSource(
        http: ref.watch(httpClientProvider),
        secureStorage: ref.watch(secureStorageProvider),
      );
    });

final Provider<AuthLocalDataSource> authLocalDataSourceProvider =
    Provider<AuthLocalDataSource>((ref) {
      return AuthLocalDataSource(
        database: ref.watch(appDatabaseProvider),
        secureStorage: ref.watch(secureStorageProvider),
      );
    });

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      return AuthRepositoryImpl(
        remote: ref.watch(authRemoteDataSourceProvider),
        local: ref.watch(authLocalDataSourceProvider),
        logger: ref.watch(authLoggerProvider),
      );
    });

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(authRepositoryProvider)),
);

final Provider<SessionCoordinator> sessionCoordinatorProvider =
    Provider<SessionCoordinator>((ref) {
      final coordinator = SessionCoordinator(
        authService: ref.watch(authServiceProvider),
        logger: ref.watch(authLoggerProvider),
      );

      ref.onDispose(coordinator.dispose);

      return coordinator;
    });

/// The cross-feature contract. Conversations depends on *this*, never on
/// `SessionCoordinator` -- which is what keeps the feature boundary real.
final Provider<SessionCapability> sessionCapabilityProvider =
    Provider<SessionCapability>((ref) => ref.watch(sessionCoordinatorProvider));

/// One renewal shared by the socket and HTTP. The backend's refresh tokens are
/// single-use, so two transports renewing independently would sign members out.
final Provider<TokenRefresher> tokenRefresherProvider =
    Provider<TokenRefresher>(
      (ref) => TokenRefresher(ref.watch(sessionCoordinatorProvider)),
    );

final Provider<AuthSocketCredentials> socketCredentialsProvider =
    Provider<AuthSocketCredentials>((ref) {
      return AuthSocketCredentials(
        repository: ref.watch(authRepositoryProvider),
        refresher: ref.watch(tokenRefresherProvider),
      );
    });

// ---------------------------------------------------------------------------
// Conversations feature
// ---------------------------------------------------------------------------

final Provider<ConversationRemoteDataSource>
conversationRemoteDataSourceProvider = Provider<ConversationRemoteDataSource>(
  (ref) => ConversationRemoteDataSource(ref.watch(socketManagerProvider)),
);

final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((ref) {
      return ConversationRepositoryImpl(
        dao: ref.watch(appDatabaseProvider).conversationDao,
        remote: ref.watch(conversationRemoteDataSourceProvider),
        logger: ref.watch(databaseLoggerProvider),
      );
    });

final Provider<MessageRepository> messageRepositoryProvider =
    Provider<MessageRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);

      return MessageRepositoryImpl(
        dao: database.conversationDao,
        outbox: database.outboxDao,
        remote: ref.watch(conversationRemoteDataSourceProvider),
        logger: ref.watch(databaseLoggerProvider),
      );
    });

final Provider<ConversationService> conversationServiceProvider =
    Provider<ConversationService>(
      (ref) => ConversationService(ref.watch(conversationRepositoryProvider)),
    );

/// Generates message idempotency keys.
///
/// Injected rather than called inline so a test can make ids deterministic --
/// asserting on a retry reusing its key is impossible against a real v4 uuid.
final Provider<String Function()> idGeneratorProvider =
    Provider<String Function()>((ref) {
      const uuid = Uuid();

      return uuid.v4;
    });

final Provider<MessageService> messageServiceProvider =
    Provider<MessageService>((ref) {
      return MessageService(
        repository: ref.watch(messageRepositoryProvider),
        conversationService: ref.watch(conversationServiceProvider),
        idGenerator: ref.watch(idGeneratorProvider),
      );
    });

final Provider<OutboxCoordinator> outboxCoordinatorProvider =
    Provider<OutboxCoordinator>((ref) {
      final database = ref.watch(appDatabaseProvider);

      final coordinator = OutboxCoordinator(
        database: database,
        outbox: database.outboxDao,
        messages: ref.watch(messageRepositoryProvider),
        remote: ref.watch(conversationRemoteDataSourceProvider),
        logger: ref.watch(syncLoggerProvider),
      );

      ref.onDispose(coordinator.dispose);

      return coordinator;
    });

final Provider<ConversationSyncCoordinator> conversationSyncProvider =
    Provider<ConversationSyncCoordinator>((ref) {
      final coordinator = ConversationSyncCoordinator(
        conversations: ref.watch(conversationRepositoryProvider),
        syncDao: ref.watch(appDatabaseProvider).syncDao,
        outbox: ref.watch(outboxCoordinatorProvider),
        logger: ref.watch(syncLoggerProvider),
      );

      ref.onDispose(coordinator.dispose);

      return coordinator;
    });

final Provider<ConversationSocketHandler> conversationSocketHandlerProvider =
    Provider<ConversationSocketHandler>((ref) {
      final handler = ConversationSocketHandler(
        conversations: ref.watch(conversationRepositoryProvider),
        messages: ref.watch(messageRepositoryProvider),
        syncDao: ref.watch(appDatabaseProvider).syncDao,
        logger: ref.watch(socketLoggerProvider),
      );

      ref.onDispose(handler.dispose);

      return handler;
    });

// ---------------------------------------------------------------------------
// Customers feature
// ---------------------------------------------------------------------------

final Provider<CustomerRemoteDataSource> customerRemoteDataSourceProvider =
    Provider<CustomerRemoteDataSource>(
      (ref) => CustomerRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<CustomerRepository> customerRepositoryProvider =
    Provider<CustomerRepository>((ref) {
      return CustomerRepositoryImpl(
        dao: ref.watch(appDatabaseProvider).customerDao,
        remote: ref.watch(customerRemoteDataSourceProvider),
        clock: DateTime.now,
      );
    });

final Provider<CustomerSyncCoordinator> customerSyncProvider =
    Provider<CustomerSyncCoordinator>((ref) {
      return CustomerSyncCoordinator(
        customers: ref.watch(customerRepositoryProvider),
        syncDao: ref.watch(appDatabaseProvider).syncDao,
        logger: ref.watch(syncLoggerProvider),
      );
    });

/// The contact directory, as other features see it.
///
/// Exposed as the contract rather than the coordinator, so a feature that
/// depends on this provider cannot reach past what the contract allows -- the
/// boundary is a type here, not a convention.
final Provider<CustomerDirectoryCapability> customerDirectoryProvider =
    Provider<CustomerDirectoryCapability>((ref) {
      return CustomerDirectoryCoordinator(
        customers: ref.watch(customerRepositoryProvider),
        sync: ref.watch(customerSyncProvider),
      );
    });
