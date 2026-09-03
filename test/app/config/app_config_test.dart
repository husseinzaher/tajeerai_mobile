import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/config/app_config.dart';
import 'package:tajeerai_mobile/app/config/environment.dart';

void main() {
  group('Environment', () {
    test('defaults to development when the define is absent', () {
      // The safe default: a debug build never points at production data by
      // accident.
      expect(Environment.resolve(), Environment.development);
    });

    test('only production is production', () {
      expect(Environment.production.isProduction, isTrue);
      expect(Environment.staging.isProduction, isFalse);
      expect(Environment.development.isProduction, isFalse);
    });

    test('verbose diagnostics are off in production only', () {
      expect(Environment.development.verboseDiagnostics, isTrue);
      expect(Environment.staging.verboseDiagnostics, isTrue);
      expect(Environment.production.verboseDiagnostics, isFalse);
    });
  });

  group('AppConfig', () {
    test('resolves from compile-time defines', () {
      final config = AppConfig.resolve();

      expect(config.environment, Environment.development);
      expect(config.apiBaseUrl, isNotEmpty);
    });

    test('serves the API and socket from one origin', () {
      final config = AppConfig.resolve();

      // The backend serves its Socket.IO gateway from the Nest application
      // itself; two independently configurable values would let them drift
      // apart in a way the server does not support.
      expect(config.socketUrl, config.apiBaseUrl);
    });

    test('the command timeout is separate from the receive timeout', () {
      const config = AppConfig(
        environment: Environment.development,
        apiBaseUrl: 'http://localhost',
        socketUrl: 'http://localhost',
        connectTimeout: Duration(seconds: 15),
        receiveTimeout: Duration(seconds: 30),
        commandTimeout: Duration(seconds: 20),
      );

      // An unanswered socket command is not a dead connection; treating it as
      // one would tear down a working socket because a handler was slow.
      expect(config.commandTimeout, isNot(config.receiveTimeout));
    });
  });
}
