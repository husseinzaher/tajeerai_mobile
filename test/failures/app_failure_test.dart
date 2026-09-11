import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';

void main() {
  group('ValidationFailure', () {
    test('exposes field errors by name', () {
      const failure = ValidationFailure(
        message: 'Check the details.',
        fieldErrors: <String, List<String>>{
          'identifier': <String>['identifier.required'],
        },
      );

      expect(failure.errorsFor('identifier'), <String>['identifier.required']);
      expect(failure.errorsFor('password'), isEmpty);
    });
  });

  group('AuthenticationFailure', () {
    test('separates a rejected sign-in from an expired session', () {
      const rejected = AuthenticationFailure(message: 'Bad credentials.');
      const expired = AuthenticationFailure(
        message: 'Session ended.',
        sessionExpired: true,
      );

      // The two warrant different copy: only one should tell the user their
      // session ended.
      expect(rejected.sessionExpired, isFalse);
      expect(expired.sessionExpired, isTrue);
    });
  });

  group('TransportFailure', () {
    test('separates being offline from a bad server response', () {
      const offline = TransportFailure(message: 'No route.', isOffline: true);
      const server = TransportFailure(message: 'Boom.', statusCode: 500);

      expect(offline.isOffline, isTrue);
      expect(server.isOffline, isFalse);
      expect(server.statusCode, 500);
    });
  });

  group('RateLimitedFailure', () {
    test('carries how long the server asked the client to wait', () {
      const said = RateLimitedFailure(
        message: 'Slow down.',
        retryAfter: Duration(seconds: 30),
      );
      const unsaid = RateLimitedFailure(message: 'Slow down.');

      expect(said.retryAfter, const Duration(seconds: 30));
      // The server does not always say. Null means "a moment", not "now".
      expect(unsaid.retryAfter, isNull);
    });
  });

  group('SocketFailure', () {
    test('carries retryability so the outbox can decide without a socket', () {
      const retryable = SocketFailure(message: 'Timed out.');
      const permanent = SocketFailure(
        message: 'Rejected.',
        isRetryable: false,
        code: 'CONFLICT',
      );

      expect(retryable.isRetryable, isTrue);
      expect(permanent.isRetryable, isFalse);
      expect(permanent.code, 'CONFLICT');
    });
  });

  group('asAppFailure', () {
    test('passes an existing failure through unchanged', () {
      const original = ConflictFailure(message: 'Already archived.');

      expect(identical(asAppFailure(original), original), isTrue);
    });

    test('wraps anything else as unknown, keeping the cause for the log', () {
      final error = StateError('unexpected');
      final failure = asAppFailure(error, 'Could not do the thing.');

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, 'Could not do the thing.');
      expect(failure.cause, same(error));
    });

    test('is exhaustive over the taxonomy', () {
      // A switch over the sealed hierarchy must compile without a default --
      // which is the point of sealing it. Adding a failure type turns every
      // unconsidered handler into a compile error rather than a silent
      // fall-through.
      String describe(AppFailure failure) => switch (failure) {
        ValidationFailure() => 'validation',
        AuthenticationFailure() => 'authentication',
        AuthorizationFailure() => 'authorization',
        NotFoundFailure() => 'notFound',
        ConflictFailure() => 'conflict',
        TransportFailure() => 'transport',
        RateLimitedFailure() => 'rateLimited',
        SocketFailure() => 'socket',
        DatabaseFailure() => 'database',
        SynchronizationFailure() => 'synchronization',
        UnknownFailure() => 'unknown',
      };

      expect(describe(const ConflictFailure(message: '')), 'conflict');
      expect(describe(const DatabaseFailure(message: '')), 'database');
    });
  });
}
