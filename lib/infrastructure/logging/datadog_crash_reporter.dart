import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';

import 'crash_reporter.dart';

/// Sends crash reports, breadcrumbs and the user id to Datadog as well as
/// the reporter it wraps.
///
/// An opaque user id only. Name, email and phone stay off the event: the
/// [CrashReporter.identify] contract already forbids them, and this
/// implementation does not grow a parameter that could carry them.
class DatadogCrashReporter implements CrashReporter {
  DatadogCrashReporter(this._inner, {DatadogSdk? sdk})
    : _sdk = sdk ?? DatadogSdk.instance;

  final CrashReporter _inner;
  final DatadogSdk _sdk;

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    _inner.report(error, stackTrace, context: context);
    _sdk.rum?.addErrorInfo(
      context == null ? '$error' : '$context: $error',
      RumErrorSource.source,
      stackTrace: stackTrace,
    );
  }

  @override
  void leaveBreadcrumb(String message, {Map<String, Object?>? data}) {
    _inner.leaveBreadcrumb(message, data: data);
    _sdk.rum?.addAction(RumActionType.custom, message, data ?? const {});
  }

  @override
  void identify(String? userId) {
    _inner.identify(userId);

    if (userId == null) {
      _sdk.clearUserInfo();
      return;
    }

    _sdk.setUserInfo(id: userId);
  }
}
