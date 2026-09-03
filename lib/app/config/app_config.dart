import 'environment.dart';

/// The resolved configuration for one run of the app.
///
/// Immutable and passed through dependency injection rather than read from
/// statics at the point of use, so a test can construct one pointing at a
/// fake server without touching global state.
///
/// ## Two origins
///
/// The API and the socket are separate hosts in production
/// (`api.tajeerai.com` and `socket.tajeerai.com`), so they are configured
/// independently. Locally they collapse onto one origin, because a single Nest
/// process serves both.
///
/// The split has one consequence worth stating: the session cookies the API
/// sets on its own domain are **not** sent to the socket host. That costs this
/// client nothing, because it never relied on cookie scope reaching the
/// socket -- `AuthRemoteDataSource` reads the access token's value out of the
/// jar and the handshake carries it as `auth.token`. A browser client would
/// need a different arrangement.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.socketUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.commandTimeout,
  });

  /// Builds the configuration from compile-time defines.
  ///
  /// `TAJEER_API_URL` and `TAJEER_SOCKET_URL` each override their
  /// per-environment default. Passing only `TAJEER_API_URL` also points the
  /// socket at it, which is what a developer running the whole backend on one
  /// LAN address wants -- the split only matters where the two are genuinely
  /// deployed apart.
  factory AppConfig.resolve() {
    final environment = Environment.resolve();

    const apiOverride = String.fromEnvironment('TAJEER_API_URL');
    const socketOverride = String.fromEnvironment('TAJEER_SOCKET_URL');

    final apiBaseUrl = apiOverride.isNotEmpty
        ? apiOverride
        : _defaultApiUrl(environment);

    final socketUrl = switch ((socketOverride, apiOverride)) {
      (final socket, _) when socket.isNotEmpty => socket,
      // An API override with no socket override means "one host, both roles".
      (_, final api) when api.isNotEmpty => api,
      _ => _defaultSocketUrl(environment),
    };

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      socketUrl: socketUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      commandTimeout: const Duration(seconds: 20),
    );
  }

  final Environment environment;

  /// Origin for the HTTP API. Routes are versioned under `/v1`, matching the
  /// backend's `@Controller('v1/auth')`.
  final String apiBaseUrl;

  /// Origin for the Socket.IO connection.
  ///
  /// A different host from [apiBaseUrl] in production. See the class comment
  /// for why that is safe for authentication.
  final String socketUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// How long a socket command waits for its acknowledgement before failing.
  ///
  /// Separate from [receiveTimeout]: an unanswered socket command is not a
  /// dead connection, and treating it as one would tear down a working socket
  /// because one handler was slow.
  final Duration commandTimeout;

  static String _defaultApiUrl(Environment environment) {
    return switch (environment) {
      // 10.0.2.2 is the host machine as seen from the Android emulator; a
      // physical device needs TAJEER_API_URL pointed at the LAN address.
      Environment.development => 'http://10.0.2.2:3000',
      Environment.staging => 'https://api.staging.tajeerai.com',
      Environment.production => 'https://api.tajeerai.com',
    };
  }

  static String _defaultSocketUrl(Environment environment) {
    return switch (environment) {
      // One local Nest process serves both roles.
      Environment.development => 'http://10.0.2.2:3000',
      Environment.staging => 'https://socket.staging.tajeerai.com',
      Environment.production => 'https://socket.tajeerai.com',
    };
  }
}
