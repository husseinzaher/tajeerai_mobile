import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/application/contracts/session_capability.dart';
import '../../features/auth/application/coordinators/session_coordinator.dart';
import '../../features/auth/application/coordinators/social_sign_in_coordinator.dart';
import '../../infrastructure/adapters/auth/local/auth_local_data_source.dart';
import '../../infrastructure/adapters/auth/remote/auth_remote_data_source.dart';
import '../../infrastructure/adapters/auth/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/services/auth_service.dart';
import '../../infrastructure/adapters/auth/realtime/auth_socket_credentials.dart';
import '../../features/conversations/application/coordinators/conversation_presence_coordinator.dart';
import '../../features/conversations/application/coordinators/conversation_sync_coordinator.dart';
import '../../features/conversations/application/coordinators/message_media_coordinator.dart';
import '../../features/conversations/application/coordinators/outbox_coordinator.dart';
import '../../features/conversations/application/events/typing_changed.dart';
import '../../features/conversations/application/ports/attachment_picker.dart';
import '../../features/conversations/application/ports/conversation_media_port.dart';
import '../../features/conversations/application/ports/conversation_remote_port.dart';
import '../../features/conversations/application/ports/voice_recorder.dart';
import '../../infrastructure/adapters/conversations/device/media_picker.dart';
import '../../infrastructure/adapters/conversations/device/record_voice_recorder.dart';
import '../../infrastructure/adapters/conversations/remote/conversation_media_remote_data_source.dart';
import '../../infrastructure/adapters/conversations/remote/conversation_remote_data_source.dart';
import '../../infrastructure/adapters/conversations/repositories/conversation_repository_impl.dart';
import '../../infrastructure/adapters/conversations/repositories/message_repository_impl.dart';
import '../../features/conversations/domain/repositories/conversation_repository.dart';
import '../../features/conversations/domain/repositories/message_repository.dart';
import '../../features/conversations/domain/services/conversation_service.dart';
import '../../features/conversations/domain/services/message_service.dart';
import '../../infrastructure/adapters/conversations/realtime/conversation_socket_handler.dart';
import '../../features/caller_id/application/coordinators/caller_id_settings_coordinator.dart';
import '../../features/caller_id/application/coordinators/caller_lookup_coordinator.dart';
import '../../features/caller_id/application/ports/caller_id_platform_port.dart';
import '../../infrastructure/adapters/caller_id/local/caller_id_settings_store.dart';
import '../../infrastructure/adapters/caller_id/platform/caller_id_platform_adapter.dart';
import '../../infrastructure/adapters/caller_id/remote/caller_lookup_remote_data_source.dart';
import '../../infrastructure/adapters/caller_id/repositories/caller_id_settings_repository_impl.dart';
import '../../infrastructure/adapters/caller_id/repositories/caller_lookup_repository_impl.dart';
import '../../features/caller_id/domain/repositories/caller_id_settings_repository.dart';
import '../../features/caller_id/domain/repositories/caller_lookup_repository.dart';
import '../../features/customers/application/contracts/customer_directory_capability.dart';
import '../../features/customers/application/coordinators/customer_directory_coordinator.dart';
import '../../features/customers/application/coordinators/customer_sync_coordinator.dart';
import '../../infrastructure/adapters/blog/remote/blog_remote_data_source.dart';
import '../../infrastructure/adapters/blog/repositories/blog_repository_impl.dart';
import '../../features/blog/domain/repositories/blog_repository.dart';
import '../../infrastructure/adapters/customers/remote/customer_remote_data_source.dart';
import '../../infrastructure/adapters/customers/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/application/contracts/customer_record_capability.dart';
import '../../features/customers/application/coordinators/customer_record_coordinator.dart';
import '../../features/orders/application/contracts/customer_orders_capability.dart';
import '../../features/orders/application/coordinators/customer_orders_coordinator.dart';
import '../../features/orders/domain/repositories/customer_order_repository.dart';
import '../../infrastructure/adapters/orders/remote/order_remote_data_source.dart';
import '../../features/conversations/domain/repositories/conversation_record_repository.dart';
import '../../infrastructure/adapters/conversations/remote/conversation_record_remote_data_source.dart';
import '../../infrastructure/adapters/conversations/repositories/conversation_record_repository_impl.dart';
import '../../infrastructure/adapters/orders/repositories/customer_order_repository_impl.dart';
import '../../infrastructure/storage/database/app_database.dart';
import '../../infrastructure/device/connectivity/connectivity_monitor.dart';
import '../../infrastructure/device/platform_info.dart';
import '../../infrastructure/logging/crash_reporter.dart';
import '../../infrastructure/logging/logger.dart';
import '../../infrastructure/api/configuration/http_configuration.dart';
import '../../infrastructure/api/http_client.dart';
import '../../infrastructure/api/token_refresher.dart';
import '../../infrastructure/socket/socket_client.dart';
import '../../infrastructure/socket/socket_connection.dart';
import '../../infrastructure/socket/socket_manager.dart';
import '../../infrastructure/storage/file_storage.dart';
import '../../infrastructure/storage/preferences_storage.dart';
import '../../infrastructure/device/google_sign_in/google_sign_in_gateway.dart';
import '../../infrastructure/device/web_auth/web_authenticator.dart';
import '../../infrastructure/security/pkce.dart';
import '../../infrastructure/storage/secure_storage.dart';
import '../config/app_config.dart';
import '../../features/wallet/application/coordinators/top_up_coordinator.dart';
import '../../features/wallet/application/ports/store_billing_port.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../infrastructure/adapters/wallet/device/play_billing_adapter.dart';
import '../../infrastructure/adapters/wallet/remote/wallet_remote_data_source.dart';
import '../../infrastructure/adapters/wallet/repositories/wallet_repository_impl.dart';

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
  final AppConfig config = ref.watch(appConfigProvider);

  return HttpClient.create(
    // The network layer is told its addresses rather than reading the app's
    // configuration: infrastructure does not reach up into `app/`.
    config: HttpConfiguration(
      apiRoot: config.apiRoot,
      origin: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
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

/// The system browser, for the one flow that needs one.
final Provider<WebAuthenticator> webAuthenticatorProvider =
    Provider<WebAuthenticator>((ref) => const PlatformWebAuthenticator());

final Provider<GoogleSignInGateway> googleSignInGatewayProvider =
    Provider<GoogleSignInGateway>((ref) => const PlatformGoogleSignInGateway());

/// Signing in with a provider.
///
/// Its own coordinator rather than a branch inside `SessionCoordinator`: the
/// round trip leaves the app, comes back through a URL the operating system
/// routes, and carries a secret of its own for the length of it.
final Provider<SocialSignInCoordinator> socialSignInProvider =
    Provider<SocialSignInCoordinator>((ref) {
      return SocialSignInCoordinator(
        repository: ref.watch(authRepositoryProvider),
        browser: ref.watch(webAuthenticatorProvider),
        google: ref.watch(googleSignInGatewayProvider),
        logger: ref.watch(authLoggerProvider),
        pkce: const PkceGenerator(),
      );
    });

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

/// The server, as the feature's application layer sees it.
///
/// Exposed as the port rather than the adapter, so a coordinator that depends
/// on this provider cannot reach past what the port allows -- the boundary is
/// a type here, not a convention. The adapter behind it is the only class in
/// the app that knows the server is reached over Socket.IO.
final Provider<ConversationRemotePort> conversationRemotePortProvider =
    Provider<ConversationRemotePort>(
      (ref) => ConversationRemoteDataSource(ref.watch(socketManagerProvider)),
    );

/// Attachment upload and download, over HTTP -- the one part of the
/// conversation feature that is not a socket frame (ARCHITECTURE.md §11).
final Provider<ConversationMediaPort> conversationMediaPortProvider =
    Provider<ConversationMediaPort>(
      (ref) => ConversationMediaRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<ConversationRepository> conversationRepositoryProvider =
    Provider<ConversationRepository>((ref) {
      return ConversationRepositoryImpl(
        dao: ref.watch(appDatabaseProvider).conversationDao,
        remote: ref.watch(conversationRemotePortProvider),
        logger: ref.watch(databaseLoggerProvider),
      );
    });

final Provider<MessageRepository> messageRepositoryProvider =
    Provider<MessageRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);

      return MessageRepositoryImpl(
        dao: database.conversationDao,
        outbox: database.outboxDao,
        remote: ref.watch(conversationRemotePortProvider),
        storage: ref.watch(fileStorageProvider),
        logger: ref.watch(databaseLoggerProvider),
      );
    });

final Provider<MessageMediaCoordinator> messageMediaCoordinatorProvider =
    Provider<MessageMediaCoordinator>((ref) {
      return MessageMediaCoordinator(
        messages: ref.watch(messageRepositoryProvider),
        remote: ref.watch(conversationMediaPortProvider),
        storage: ref.watch(fileStorageProvider),
        logger: ref.watch(syncLoggerProvider),
      );
    });

/// Picks a file for the composer and stages it where the outbox can read it.
final Provider<AttachmentPicker> attachmentPickerProvider =
    Provider<AttachmentPicker>(
      (ref) => MediaPicker(storage: ref.watch(fileStorageProvider)),
    );

/// Makes a voice recorder for one thread screen.
///
/// A factory rather than an instance: a recorder holds an encoder and a timer
/// for exactly as long as a screen is open, and the screen is what disposes
/// it. Exposed as the port, so the screen never names the plugin behind it.
final Provider<VoiceRecorder Function()> voiceRecorderFactoryProvider =
    Provider<VoiceRecorder Function()>((ref) => RecordVoiceRecorder.new);

/// A thread's own record - notes, log lines, summaries - over HTTP, which is
/// the one transport the backend offers for it (ARCHITECTURE.md §11).
final Provider<ConversationRecordRemoteDataSource>
conversationRecordRemoteDataSourceProvider =
    Provider<ConversationRecordRemoteDataSource>(
      (ref) =>
          ConversationRecordRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<ConversationRecordRepository>
conversationRecordRepositoryProvider = Provider<ConversationRecordRepository>((
  ref,
) {
  return ConversationRecordRepositoryImpl(
    dao: ref.watch(appDatabaseProvider).conversationNoteDao,
    remote: ref.watch(conversationRecordRemoteDataSourceProvider),
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
        remote: ref.watch(conversationRemotePortProvider),
        media: ref.watch(conversationMediaPortProvider),
        logger: ref.watch(syncLoggerProvider),
      );

      ref.onDispose(coordinator.dispose);

      return coordinator;
    });

/// Holds the member's seat in whatever threads are open.
///
/// A `Provider` rather than something the screen owns, because the seat has to
/// outlive a single build and be replayed on every reconnection -- see the
/// coordinator's own note on why joining once is not enough.
final Provider<ConversationPresenceCoordinator> conversationPresenceProvider =
    Provider<ConversationPresenceCoordinator>((ref) {
      final coordinator = ConversationPresenceCoordinator(
        remote: ref.watch(conversationRemotePortProvider),
        logger: ref.watch(socketLoggerProvider),
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

/// Typing bubbles, as the realtime adapter reports them.
///
/// A stream of the application's own event type, so the controller that shows
/// a bubble depends on the feature's vocabulary and never on the adapter that
/// decoded the frame.
final Provider<Stream<TypingChanged>> conversationTypingEventsProvider =
    Provider<Stream<TypingChanged>>(
      (ref) => ref.watch(conversationSocketHandlerProvider).transientEvents,
    );

// ---------------------------------------------------------------------------
// Blog feature
// ---------------------------------------------------------------------------

/*
  The only feature in this app that reads without a session, and the only one
  with no local database behind it. Both facts are recorded in
  ARCHITECTURE.md §11: the socket cannot serve a guest because its handshake
  carries a token, and the workspace database is emptied on sign-out, which is
  the wrong lifetime for content a guest reads.
*/
final Provider<BlogRemoteDataSource> blogRemoteDataSourceProvider =
    Provider<BlogRemoteDataSource>(
      (ref) => BlogRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<BlogRepository> blogRepositoryProvider =
    Provider<BlogRepository>(
      (ref) =>
          BlogRepositoryImpl(remote: ref.watch(blogRemoteDataSourceProvider)),
    );

// ---------------------------------------------------------------------------
// Wallet feature
// ---------------------------------------------------------------------------

/*
  HTTP and no local database, like the blog - ARCHITECTURE.md §11: the backend
  serves the wallet and billing over HTTP alone, a purchase is online by
  nature, and a cached balance is a number somebody acts on after it stopped
  being true.
*/
final Provider<WalletRemoteDataSource> walletRemoteDataSourceProvider =
    Provider<WalletRemoteDataSource>(
      (ref) => WalletRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<WalletRepository> walletRepositoryProvider =
    Provider<WalletRepository>(
      (ref) => WalletRepositoryImpl(
        remote: ref.watch(walletRemoteDataSourceProvider),
      ),
    );

/// Google Play on Android; nothing to buy from anywhere else. iOS shows the
/// wallet read-only for now (owner, 2026-10-03) - Apple requires its own
/// in-app purchase for digital goods, which is a separate integration.
final Provider<StoreBillingPort> storeBillingPortProvider =
    Provider<StoreBillingPort>((ref) {
      if (ref.watch(platformInfoProvider).operatingSystem == 'android') {
        return PlayBillingAdapter();
      }

      return const UnavailableStoreBillingAdapter();
    });

final Provider<TopUpCoordinator> topUpCoordinatorProvider =
    Provider<TopUpCoordinator>((ref) {
      final TopUpCoordinator coordinator = TopUpCoordinator(
        repository: ref.watch(walletRepositoryProvider),
        store: ref.watch(storeBillingPortProvider),
      );

      ref.onDispose(coordinator.dispose);

      return coordinator;
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

/// A contact's record, as the conversation screen's customer panel reads it.
///
/// The contract, not the repository, for the reason `customerDirectoryProvider`
/// is: another feature depending on this cannot reach past what it allows.
final Provider<CustomerRecordCapability> customerRecordProvider =
    Provider<CustomerRecordCapability>((ref) {
      return CustomerRecordCoordinator(
        customers: ref.watch(customerRepositoryProvider),
      );
    });

// ---------------------------------------------------------------------------
// Orders feature
// ---------------------------------------------------------------------------

final Provider<OrderRemoteDataSource> orderRemoteDataSourceProvider =
    Provider<OrderRemoteDataSource>(
      (ref) => OrderRemoteDataSource(ref.watch(httpClientProvider)),
    );

final Provider<CustomerOrderRepository> customerOrderRepositoryProvider =
    Provider<CustomerOrderRepository>((ref) {
      return CustomerOrderRepositoryImpl(
        dao: ref.watch(appDatabaseProvider).orderDao,
        remote: ref.watch(orderRemoteDataSourceProvider),
      );
    });

/// A contact's recent orders, as other features see them.
final Provider<CustomerOrdersCapability> customerOrdersProvider =
    Provider<CustomerOrdersCapability>((ref) {
      return CustomerOrdersCoordinator(
        orders: ref.watch(customerOrderRepositoryProvider),
      );
    });

// ---------------------------------------------------------------------------
// Caller ID feature
// ---------------------------------------------------------------------------

final Provider<CallerIdPlatformPort> callerIdPlatformPortProvider =
    Provider<CallerIdPlatformPort>((ref) {
      if (ref.watch(platformInfoProvider).operatingSystem == 'android') {
        return CallerIdPlatformAdapter();
      }

      return const NoopCallerIdPlatformAdapter();
    });

final Provider<CallerIdSettingsStore> callerIdSettingsStoreProvider =
    Provider<CallerIdSettingsStore>(
      (ref) => CallerIdSettingsStore(ref.watch(preferencesStorageProvider)),
    );

final Provider<CallerIdSettingsRepository> callerIdSettingsRepositoryProvider =
    Provider<CallerIdSettingsRepository>(
      (ref) => CallerIdSettingsRepositoryImpl(
        ref.watch(callerIdSettingsStoreProvider),
      ),
    );

final Provider<CallerLookupRemoteDataSource>
callerLookupRemoteDataSourceProvider = Provider<CallerLookupRemoteDataSource>(
  (ref) => CallerLookupRemoteDataSource(ref.watch(httpClientProvider)),
);

final Provider<CallerLookupRepository> callerLookupRepositoryProvider =
    Provider<CallerLookupRepository>((ref) {
      return CallerLookupRepositoryImpl(
        cache: ref.watch(appDatabaseProvider).callerIdentityCacheDao,
        directory: ref.watch(customerDirectoryProvider),
        remote: ref.watch(callerLookupRemoteDataSourceProvider),
      );
    });

final Provider<CallerLookupCoordinator> callerLookupCoordinatorProvider =
    Provider<CallerLookupCoordinator>(
      (ref) => CallerLookupCoordinator(
        repository: ref.watch(callerLookupRepositoryProvider),
      ),
    );

final Provider<CallerIdSettingsCoordinator>
callerIdSettingsCoordinatorProvider = Provider<CallerIdSettingsCoordinator>(
  (ref) => CallerIdSettingsCoordinator(
    settings: ref.watch(callerIdSettingsRepositoryProvider),
    platform: ref.watch(callerIdPlatformPortProvider),
  ),
);
