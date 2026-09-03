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

    test('resolves the API and the socket independently', () {
      // They are separate hosts in staging and production
      // (api.tajeerai.com / socket.tajeerai.com), so neither is derived from
      // the other.
      final config = AppConfig.resolve();

      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.socketUrl, isNotEmpty);
    });

    test(
      'collapses onto one origin locally, where one process serves both',
      () {
        // With no defines, development is the resolved environment and a single
        // Nest process serves the API and the gateway.
        final config = AppConfig.resolve();

        expect(config.environment, Environment.development);
        expect(config.socketUrl, config.apiBaseUrl);
      },
    );

    test('holds two distinct origins when given them', () {
      const config = AppConfig(
        environment: Environment.production,
        apiBaseUrl: 'https://api.tajeerai.com',
        socketUrl: 'https://socket.tajeerai.com',
        connectTimeout: Duration(seconds: 15),
        receiveTimeout: Duration(seconds: 30),
        commandTimeout: Duration(seconds: 20),
      );

      // The split is safe for authentication because the client never relied
      // on the API's cookies reaching the socket host: the access token is
      // read out of the jar and carried on the handshake as `auth.token`.
      expect(config.apiBaseUrl, isNot(config.socketUrl));
      expect(Uri.parse(config.socketUrl).host, 'socket.tajeerai.com');
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
