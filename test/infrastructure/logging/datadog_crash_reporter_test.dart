import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/logging/crash_reporter.dart';
import 'package:TajeerAi/infrastructure/logging/datadog_crash_reporter.dart';

class _RecordingReporter implements CrashReporter {
  final List<Object> errors = <Object>[];
  final List<String> breadcrumbs = <String>[];
  final List<String?> users = <String?>[];

  @override
  void report(Object error, StackTrace stackTrace, {String? context}) {
    errors.add(error);
  }

  @override
  void leaveBreadcrumb(String message, {Map<String, Object?>? data}) {
    breadcrumbs.add(message);
  }

  @override
  void identify(String? userId) {
    users.add(userId);
  }
}

void main() {
  late _RecordingReporter inner;
  late DatadogCrashReporter reporter;

  setUp(() {
    DatadogSdk.initializeForTesting();
    inner = _RecordingReporter();
    reporter = DatadogCrashReporter(inner);
  });

  test('keeps the local report when RUM is not started', () {
    final error = StateError('boom');

    expect(
      () => reporter.report(error, StackTrace.current, context: 'zone'),
      returnsNormally,
    );
    expect(inner.errors, <Object>[error]);
  });

  test('records a breadcrumb locally', () {
    expect(() => reporter.leaveBreadcrumb('opened a thread'), returnsNormally);
    expect(inner.breadcrumbs, <String>['opened a thread']);
  });

  test('associates and clears an opaque user id', () {
    expect(() => reporter.identify('u1'), returnsNormally);
    expect(() => reporter.identify(null), returnsNormally);
    expect(inner.users, <String?>['u1', null]);
  });
}
