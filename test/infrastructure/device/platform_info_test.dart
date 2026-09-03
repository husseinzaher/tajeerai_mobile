import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/infrastructure/device/connectivity/connectivity_monitor.dart';
import 'package:tajeerai_mobile/infrastructure/device/platform_info.dart';

void main() {
  group('PlatformInfo', () {
    test('builds a user agent identifying the client to the backend', () {
      const info = PlatformInfo(
        appVersion: '1.2.3',
        buildNumber: '45',
        operatingSystem: 'android',
      );

      expect(info.userAgent, 'TajeerAI-Mobile/1.2.3+45 (android)');
    });

    test('carries no device identifier', () {
      const info = PlatformInfo(
        appVersion: '1.0.0',
        buildNumber: '1',
        operatingSystem: 'ios',
      );

      // Nothing in the app needs to tell two installations apart; collecting
      // an id anyway is how an app acquires a tracking surface by accident.
      expect(info.userAgent.split(' '), hasLength(2));
    });
  });

  group('NetworkStatus', () {
    test('models a hint, not the truth', () {
      // A captive portal reports online and answers nothing, so nothing in the
      // app treats this as proof of connectivity -- the socket's own state is
      // the authority.
      expect(NetworkStatus.values, hasLength(2));
      expect(NetworkStatus.values, contains(NetworkStatus.online));
      expect(NetworkStatus.values, contains(NetworkStatus.offline));
    });
  });
}
