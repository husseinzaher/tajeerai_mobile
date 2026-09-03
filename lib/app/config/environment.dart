/// Which deployment the binary points at.
///
/// Selected at build time with `--dart-define=TAJEER_ENV=…` rather than from a
/// file on disk, so a release build cannot be repointed at a developer's
/// machine by shipping the wrong asset.
enum Environment {
  development,
  staging,
  production;

  static const String _key = 'TAJEER_ENV';

  /// Reads the compile-time define. Unknown or absent values fall back to
  /// development, which is the safe default: it never points a debug build at
  /// production data by accident.
  static Environment resolve() {
    const raw = String.fromEnvironment(_key, defaultValue: 'development');

    return Environment.values.firstWhere(
      (environment) => environment.name == raw,
      orElse: () => Environment.development,
    );
  }

  bool get isProduction => this == Environment.production;

  /// Verbose socket and synchronisation diagnostics stay off in production --
  /// see `Logger`, which will not emit payload-level records there.
  bool get verboseDiagnostics => this != Environment.production;
}
