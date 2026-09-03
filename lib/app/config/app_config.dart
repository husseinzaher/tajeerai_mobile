import 'environment.dart';

/// The resolved configuration for one run of the app.
///
/// Immutable and passed through dependency injection rather than read from
/// statics at the point of use, so a test can construct one pointing at a
/// fake server without touching global state.
///
/// The API and socket origins are the same host: the backend serves its
/// Socket.IO gateway from the Nest application itself, so splitting them into
/// two independently configurable values would let them drift apart in a way
/// the server does not support.
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
  /// `TAJEER_API_URL` overrides the per-environment default, which is what a
  /// developer running the backend on a LAN address needs.
  factory AppConfig.resolve() {
    final environment = Environment.resolve();

    const override = String.fromEnvironment('TAJEER_API_URL');
    final baseUrl = override.isNotEmpty ? override : _defaultUrl(environment);

    return AppConfig(
      environment: environment,
      apiBaseUrl: baseUrl,
      socketUrl: baseUrl,
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
  final String socketUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// How long a socket command waits for its acknowledgement before failing.
  ///
  /// Separate from [receiveTimeout]: an unanswered socket command is not a
  /// dead connection, and treating it as one would tear down a working socket
  /// because one handler was slow.
  final Duration commandTimeout;

  static String _defaultUrl(Environment environment) {
    return switch (environment) {
      // 10.0.2.2 is the host machine as seen from the Android emulator; a
      // physical device needs TAJEER_API_URL pointed at the LAN address.
      Environment.development => 'http://10.0.2.2:3000',
      Environment.staging => 'https://staging.tajeerai.net',
      Environment.production => 'https://app.tajeerai.net',
    };
  }
}
