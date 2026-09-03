import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';

void main() {
  group('toString', () {
    test('names the type and the message', () {
      const failure = ConflictFailure(message: 'Already archived.');

      // Logs identify a failure by type; the message is the human half.
      expect(failure.toString(), contains('ConflictFailure'));
      expect(failure.toString(), contains('Already archived.'));
    });

    test('every failure type produces a readable line', () {
      final failures = <AppFailure>[
        const ValidationFailure(message: 'v'),
        const AuthenticationFailure(message: 'a'),
        const AuthorizationFailure(message: 'z'),
        const NotFoundFailure(message: 'n'),
        const ConflictFailure(message: 'c'),
        const TransportFailure(message: 't'),
        const SocketFailure(message: 's'),
        const DatabaseFailure(message: 'd'),
        const SynchronizationFailure(message: 'y'),
        const UnknownFailure(),
      ];

      for (final failure in failures) {
        expect(failure.toString(), isNotEmpty);
        expect(failure.toString(), contains(failure.runtimeType.toString()));
      }
    });
  });

  group('causes', () {
    test('are kept for logging but are not the message', () {
      final cause = StateError('inner detail');
      final failure = DatabaseFailure(
        message: 'The message could not be saved.',
        cause: cause,
      );

      expect(failure.cause, same(cause));

      // The user-facing message must not carry the internal detail.
      expect(failure.message, isNot(contains('inner detail')));
    });
  });

  group('UnknownFailure', () {
    test('has a safe default message', () {
      const failure = UnknownFailure();

      expect(failure.message, 'An unexpected error occurred.');
    });

    test('accepts a caller-supplied message', () {
      const failure = UnknownFailure(message0: 'Could not load the list.');

      expect(failure.message, 'Could not load the list.');
    });
  });

  group('ValidationFailure', () {
    test('defaults to no field errors', () {
      const failure = ValidationFailure(message: 'Invalid.');

      expect(failure.fieldErrors, isEmpty);
      expect(failure.errorsFor('anything'), isEmpty);
    });
  });

  group('is an Exception', () {
    test('so it can be thrown and caught as one', () {
      expect(const ConflictFailure(message: 'x'), isA<Exception>());

      expect(
        () => throw const ConflictFailure(message: 'x'),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
