import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/infrastructure/device/google_sign_in/google_sign_in_gateway.dart';

void main() {
  group('native client ids from the environment', () {
    test('returns null off Android', () {
      expect(androidClientIdFromEnvironment(), isNull);
    });

    test('returns null off iOS', () {
      expect(iosClientIdFromEnvironment(), isNull);
    });

    test('returns null when neither platform client id applies', () {
      expect(nativeClientIdFromEnvironment(), isNull);
    });
  });

  group('configure_google_sign_in reversed client id', () {
    test('derives the URL scheme Google expects', () {
      const String clientId = '123456789-abc.apps.googleusercontent.com';

      expect(
        _reversedClientIdForTest(clientId),
        'com.googleusercontent.apps.123456789-abc',
      );
    });

    test('rejects a web client id shape', () {
      expect(_reversedClientIdForTest('not-a-google-client'), isNull);
    });
  });
}

/// Mirrors [configure_google_sign_in.dart] so the scheme stays tested without
/// importing a script entry point.
String? _reversedClientIdForTest(String clientId) {
  const String suffix = '.apps.googleusercontent.com';

  if (!clientId.endsWith(suffix)) {
    return null;
  }

  final String prefix = clientId.substring(0, clientId.length - suffix.length);

  if (prefix.isEmpty) {
    return null;
  }

  return 'com.googleusercontent.apps.$prefix';
}
