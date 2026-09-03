import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/infrastructure/logging/crash_reporter.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

void main() {
  late LoggingCrashReporter reporter;

  setUp(() {
    reporter = LoggingCrashReporter(Logger('test', verbose: true));
  });

  group('LoggingCrashReporter', () {
    test('reports an error without throwing', () {
      expect(
        () => reporter.report(
          StateError('boom'),
          StackTrace.current,
          context: 'a test',
        ),
        returnsNormally,
      );
    });

    test('records breadcrumbs', () {
      expect(
        () => reporter.leaveBreadcrumb(
          'opened a thread',
          data: <String, Object?>{'conversationId': 'c1'},
        ),
        returnsNormally,
      );
    });

    test('associates and clears a user id', () {
      // Only an opaque id -- never an email, name or phone, which would put
      // personal data in a third-party system by default.
      expect(() => reporter.identify('u1'), returnsNormally);
      expect(() => reporter.identify(null), returnsNormally);
    });

    test('reports after being identified', () {
      reporter.identify('u1');

      expect(
        () => reporter.report(StateError('boom'), StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('handler installation', () {
    test('routes framework errors to the reporter', () {
      final previous = FlutterError.onError;

      addTearDown(() => FlutterError.onError = previous);

      installCrashHandlers(reporter);

      expect(FlutterError.onError, isNotNull);
      expect(FlutterError.onError, isNot(same(previous)));
    });

    test('runs a guarded body to completion', () async {
      var ran = false;

      await runGuardedWith(reporter, () async => ran = true);

      expect(ran, isTrue);
    });

    test('a throwing guarded body does not propagate', () async {
      // An offline-first client that closes on one bad frame is worse than one
      // that logs and carries on.
      await expectLater(
        runGuardedWith(reporter, () async => throw StateError('boom')),
        completes,
      );
    });
  });
}
