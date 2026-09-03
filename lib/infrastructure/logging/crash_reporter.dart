import 'dart:async';

import 'package:flutter/foundation.dart';

import 'logger.dart';

/// Where uncaught errors go.
///
/// An interface with a logging implementation rather than a direct Crashlytics
/// or Sentry call: the vendor is a deployment decision that has not been made,
/// and this is the seam that lets it be made later without touching a single
/// call site. Wiring a real backend means one new implementation registered in
/// `dependencies.dart` -- nothing else changes.
abstract interface class CrashReporter {
  /// Reports a caught-but-fatal error.
  void report(Object error, StackTrace stackTrace, {String? context});

  /// Records a breadcrumb leading up to a future crash.
  void leaveBreadcrumb(String message, {Map<String, Object?>? data});

  /// Associates subsequent reports with a user. Pass null on sign-out.
  ///
  /// Takes an opaque id only -- never an email, name or phone number, which
  /// would put personal data in a third-party system by default.
  void identify(String? userId);
}

/// The default reporter: writes through [Logger] and nothing else.
///
/// Deliberately a real, working implementation rather than a no-op, so errors
/// are visible in development from the first run.
class LoggingCrashReporter implements CrashReporter {
  LoggingCrashReporter(this._logger);

  final Logger _logger;
  String? _userId;

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    _logger.error(
      context == null ? 'Uncaught error' : 'Uncaught error in $context',
      error: error,
      stackTrace: stackTrace,
      data: <String, Object?>{if (_userId != null) 'userId': _userId},
    );
  }

  @override
  void leaveBreadcrumb(String message, {Map<String, Object?>? data}) {
    _logger.debug('breadcrumb: $message', data: data);
  }

  @override
  void identify(String? userId) => _userId = userId;
}

/// Installs [reporter] as the sink for errors Flutter would otherwise print.
///
/// Covers both channels: the framework's own error handler, and the
/// platform-dispatcher hook that catches errors escaping the Dart isolate --
/// an async gap in a controller lands in the second, not the first.
void installCrashHandlers(CrashReporter reporter) {
  final previous = FlutterError.onError;

  FlutterError.onError = (details) {
    previous?.call(details);
    reporter.report(
      details.exception,
      details.stack ?? StackTrace.current,
      context: details.library,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    reporter.report(error, stackTrace, context: 'PlatformDispatcher');

    // Handled: the app keeps running. An offline-first client that closes on
    // one bad socket frame is worse than one that logs and carries on.
    return true;
  };
}

/// Runs [body] in a zone whose uncaught errors reach [reporter].
///
/// The returned future always completes, including when [body] throws.
/// `runZonedGuarded` routes an async body's error to the zone handler rather
/// than to the future it returned, so awaiting that future directly would hang
/// forever on failure -- and `main` awaits this.
Future<void> runGuardedWith(
  CrashReporter reporter,
  Future<void> Function() body,
) {
  final completed = Completer<void>();

  void finish() {
    if (!completed.isCompleted) completed.complete();
  }

  runZonedGuarded<void>(
    () async {
      try {
        await body();
      } finally {
        finish();
      }
    },
    (error, stackTrace) {
      reporter.report(error, stackTrace, context: 'zone');
      finish();
    },
  );

  return completed.future;
}
