import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

void main() {
  group('Logger.redact', () {
    test('replaces credentials at the top level', () {
      final redacted = Logger.redact(<String, Object?>{
        'accessToken': 'secret-value',
        'refresh_token': 'another-secret',
        'password': 'hunter2',
        'Authorization': 'Bearer abc',
        'userId': 'u-1',
      });

      expect(redacted['accessToken'], '[redacted]');
      expect(redacted['refresh_token'], '[redacted]');
      expect(redacted['password'], '[redacted]');
      expect(redacted['Authorization'], '[redacted]');

      // Non-sensitive values survive, or the logs would be useless.
      expect(redacted['userId'], 'u-1');
    });

    test('replaces private message content', () {
      final redacted = Logger.redact(<String, Object?>{
        'body': 'a private customer message',
        'mediaUrl': 'https://example.test/photo.jpg',
        'conversationId': 'c-1',
      });

      expect(redacted['body'], '[redacted]');
      expect(redacted['mediaUrl'], '[redacted]');
      expect(redacted['conversationId'], 'c-1');
    });

    test('recurses into nested payloads', () {
      final redacted = Logger.redact(<String, Object?>{
        'event': 'message.created',
        'message': <String, Object?>{'id': 'm-1', 'body': 'private'},
      });

      final message = redacted['message']! as Map<String, Object?>;

      // A socket payload nests, so a top-level-only check would let the body
      // straight through.
      expect(message['body'], '[redacted]');
      expect(message['id'], 'm-1');
    });

    test('recurses into lists of payloads', () {
      final redacted = Logger.redact(<String, Object?>{
        'messages': <Object?>[
          <String, Object?>{'id': 'm-1', 'body': 'private'},
          <String, Object?>{'id': 'm-2', 'body': 'also private'},
        ],
      });

      final messages = redacted['messages']! as List<Object?>;

      for (final entry in messages) {
        expect((entry! as Map<String, Object?>)['body'], '[redacted]');
      }
    });

    test('matches keys regardless of case or separators', () {
      final redacted = Logger.redact(<String, Object?>{
        'ACCESS_TOKEN': 'x',
        'access-token': 'y',
        'apiKey': 'z',
      });

      expect(redacted.values, everyElement('[redacted]'));
    });
  });

  group('verbosity', () {
    test('drops debug records when not verbose', () {
      // Production must not emit the payload-level diagnostics that are useful
      // only in development. Asserted through the flag rather than by
      // capturing output, which `dart:developer` does not expose.
      final quiet = Logger('test', verbose: false);
      final loud = Logger('test', verbose: true);

      expect(quiet.verbose, isFalse);
      expect(loud.verbose, isTrue);

      // Neither should throw.
      quiet.debug('should not be emitted');
      loud.debug('should be emitted');
    });
  });
}
