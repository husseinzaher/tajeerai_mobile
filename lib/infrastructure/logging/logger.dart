import 'dart:developer' as developer;

import 'package:logging/logging.dart' as logging;

/// Severity, ordered.
enum LogLevel { debug, info, warning, error }

/// The application's logging facade.
///
/// Every log goes through here rather than `print` so that one place decides
/// what is emitted and, more importantly, what is *redacted*. Tokens,
/// passwords and message bodies must never reach a log sink -- see
/// [Logger.redact] and the `sensitiveKeys` set.
///
/// Named channels (`socket`, `sync`, `db`, `http`) keep diagnostics filterable
/// without a second logging system per subsystem.
class Logger {
  Logger(this.channel, {required this.verbose})
    : _delegate = logging.Logger(channel);

  final String channel;

  /// Debug records are dropped entirely when false, which is how production
  /// avoids emitting the diagnostic detail that is useful only in development.
  final bool verbose;

  final logging.Logger _delegate;

  /// Keys whose values are replaced before anything is written.
  ///
  /// Matched case-insensitively on a contains basis, so `accessToken`,
  /// `access_token` and `Authorization` are all caught by the same entries.
  static const Set<String> sensitiveKeys = <String>{
    'token',
    'accesstoken',
    'refreshtoken',
    'password',
    'secret',
    'authorization',
    'cookie',
    'apikey',
    'credential',
    // Message bodies are private customer content. A conversation payload may
    // be logged for its shape; never for what it says.
    'body',
    'text',
    'content',
    'caption',
    'mediaurl',
  };

  static const String _redacted = '[redacted]';

  void debug(String message, {Map<String, Object?>? data}) {
    if (!verbose) return;
    _emit(LogLevel.debug, message, data: data);
  }

  void info(String message, {Map<String, Object?>? data}) =>
      _emit(LogLevel.info, message, data: data);

  void warning(String message, {Map<String, Object?>? data, Object? error}) =>
      _emit(LogLevel.warning, message, data: data, error: error);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) => _emit(
    LogLevel.error,
    message,
    data: data,
    error: error,
    stackTrace: stackTrace,
  );

  void _emit(
    LogLevel level,
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final safe = data == null ? '' : ' ${redact(data)}';
    final line = '[$channel] $message$safe';

    developer.log(
      line,
      name: channel,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );

    // Kept in sync with the `logging` hierarchy so a host app can attach its
    // own sink without this class owning transport.
    _delegate.log(
      switch (level) {
        LogLevel.debug => logging.Level.FINE,
        LogLevel.info => logging.Level.INFO,
        LogLevel.warning => logging.Level.WARNING,
        LogLevel.error => logging.Level.SEVERE,
      },
      line,
      error,
      stackTrace,
    );
  }

  /// Replaces the value of any sensitive key, at any depth.
  ///
  /// Recurses through nested maps and lists because a socket payload nests --
  /// `{message: {body: …}}` would otherwise sail past a top-level-only check.
  static Map<String, Object?> redact(Map<String, Object?> data) {
    return data.map((key, value) => MapEntry(key, _redactValue(key, value)));
  }

  static Object? _redactValue(String key, Object? value) {
    if (_isSensitive(key)) return _redacted;

    return switch (value) {
      final Map<String, Object?> map => redact(map),
      final List<Object?> list =>
        list
            .map((item) => item is Map<String, Object?> ? redact(item) : item)
            .toList(growable: false),
      _ => value,
    };
  }

  static bool _isSensitive(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

    return sensitiveKeys.any(normalized.contains);
  }
}
