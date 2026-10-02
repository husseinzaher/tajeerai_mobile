/// Where the HTTP client sends requests, and how long it waits.
///
/// Built by the composition root from the app's resolved configuration, so the
/// network layer never imports `app/`: infrastructure is told what it needs
/// and does not reach up for it. The two addresses are distinct on purpose --
/// see `HttpClient.resolve` and `HttpClient.resolveFromOrigin`.
final class HttpConfiguration {
  const HttpConfiguration({
    required this.apiRoot,
    required this.origin,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  /// Where requests go: the API's origin plus the backend's global prefix
  /// (`https://api.tajeerai.com/api`). Routes below it are versioned.
  final String apiRoot;

  /// The API's origin alone, without the prefix. The session cookies are
  /// scoped to it, and a path that arrives inside stored content already
  /// carrying the prefix is completed against it.
  final String origin;

  final Duration connectTimeout;
  final Duration receiveTimeout;
}
