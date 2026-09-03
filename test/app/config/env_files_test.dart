import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks the committed `.env` files.
///
/// These are the artifacts builds actually consume -- CI builds the APK with
/// `--dart-define-from-file=.env.production` -- so a typo in one of them ships,
/// while the Dart defaults in `AppConfig` are only the fallback. Pinning the
/// hostnames here is what stops a build quietly pointing at the wrong server.
void main() {
  /// Parses a `.env` file into a map, ignoring comments and blank lines.
  Map<String, String> read(String name) {
    final file = File(name);

    expect(file.existsSync(), isTrue, reason: '$name is missing');

    final values = <String, String>{};

    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();

      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final separator = trimmed.indexOf('=');

      if (separator == -1) continue;

      values[trimmed.substring(0, separator).trim()] = trimmed
          .substring(separator + 1)
          .trim();
    }

    return values;
  }

  group('.env.production', () {
    late Map<String, String> env;

    setUp(() => env = read('.env.production'));

    test('selects the production environment', () {
      expect(env['TAJEER_ENV'], 'production');
    });

    test('points the API and the socket at their separate hosts', () {
      expect(env['TAJEER_API_URL'], 'https://api.tajeerai.com');
      expect(env['TAJEER_SOCKET_URL'], 'https://socket.tajeerai.com');
    });

    test('uses two distinct hosts, over https', () {
      final api = Uri.parse(env['TAJEER_API_URL']!);
      final socket = Uri.parse(env['TAJEER_SOCKET_URL']!);

      expect(api.host, isNot(socket.host));
      expect(api.scheme, 'https');
      expect(socket.scheme, 'https');
    });
  });

  group('.env.staging', () {
    late Map<String, String> env;

    setUp(() => env = read('.env.staging'));

    test('selects the staging environment', () {
      expect(env['TAJEER_ENV'], 'staging');
    });

    test('serves both roles from one host', () {
      // Unlike production. The two values are configured independently, so
      // they are free to be equal here.
      expect(env['TAJEER_API_URL'], 'https://staging.tajeerai.com');
      expect(env['TAJEER_SOCKET_URL'], 'https://staging.tajeerai.com');
    });
  });

  group('.env.development', () {
    late Map<String, String> env;

    setUp(() => env = read('.env.development'));

    test('points at the local backend on both roles', () {
      expect(env['TAJEER_ENV'], 'development');
      expect(env['TAJEER_API_URL'], env['TAJEER_SOCKET_URL']);
      expect(env['TAJEER_API_URL'], 'http://10.0.2.2:4040');
    });

    test('never points a development build at a real deployment', () {
      // The safe default: a debug build must not reach production data by
      // accident.
      expect(env['TAJEER_API_URL'], isNot(contains('tajeerai.com')));
    });
  });

  group('every committed env file', () {
    const files = <String>[
      '.env.development',
      '.env.staging',
      '.env.production',
      '.env.example',
    ];

    test('declares all three keys', () {
      for (final name in files) {
        final env = read(name);

        expect(
          env.keys,
          containsAll(<String>[
            'TAJEER_ENV',
            'TAJEER_API_URL',
            'TAJEER_SOCKET_URL',
          ]),
          reason: '$name is missing a key',
        );
      }
    });

    test('names a valid environment', () {
      for (final name in files) {
        expect(
          read(name)['TAJEER_ENV'],
          isIn(<String>['development', 'staging', 'production']),
          reason: name,
        );
      }
    });

    test('carries no secret-looking key', () {
      // These values are compiled into the binary and are extractable from a
      // shipped APK. Hostnames and flags only.
      const forbidden = <String>[
        'SECRET',
        'PASSWORD',
        'TOKEN',
        'KEY',
        'CREDENTIAL',
        'PRIVATE',
      ];

      for (final name in files) {
        for (final key in read(name).keys) {
          for (final word in forbidden) {
            expect(
              key.toUpperCase(),
              isNot(contains(word)),
              reason:
                  '$name declares "$key", which looks like a secret. '
                  'These files ship inside the binary.',
            );
          }
        }
      }
    });

    test('uses https for anything that is not localhost', () {
      for (final name in files) {
        final env = read(name);

        for (final key in <String>['TAJEER_API_URL', 'TAJEER_SOCKET_URL']) {
          final uri = Uri.parse(env[key]!);
          final isLocal =
              uri.host == '10.0.2.2' ||
              uri.host == 'localhost' ||
              uri.host == '127.0.0.1';

          if (isLocal) continue;

          expect(uri.scheme, 'https', reason: '$name -> $key');
        }
      }
    });
  });
}
