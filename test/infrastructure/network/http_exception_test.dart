import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/infrastructure/network/http_exception.dart';

void main() {
  group('status mapping', () {
    test('401 becomes an authentication failure', () {
      final failure = const HttpException(
        message: 'x',
        statusCode: 401,
      ).toFailure();

      expect(failure, isA<AuthenticationFailure>());
    });

    test('403 becomes an authorization failure', () {
      expect(
        const HttpException(message: 'x', statusCode: 403).toFailure(),
        isA<AuthorizationFailure>(),
      );
    });

    test('404 becomes a not-found failure', () {
      expect(
        const HttpException(message: 'x', statusCode: 404).toFailure(),
        isA<NotFoundFailure>(),
      );
    });

    test('409 becomes a conflict failure', () {
      expect(
        const HttpException(message: 'x', statusCode: 409).toFailure(),
        isA<ConflictFailure>(),
      );
    });

    test('400 and 422 become validation failures', () {
      expect(
        const HttpException(message: 'x', statusCode: 400).toFailure(),
        isA<ValidationFailure>(),
      );
      expect(
        const HttpException(message: 'x', statusCode: 422).toFailure(),
        isA<ValidationFailure>(),
      );
    });

    test('5xx becomes a transport failure carrying the status', () {
      final failure =
          const HttpException(message: 'x', statusCode: 503).toFailure()
              as TransportFailure;

      expect(failure.statusCode, 503);
      expect(failure.isOffline, isFalse);
    });
  });

  group('connection errors', () {
    test('become an offline transport failure', () {
      final failure =
          const HttpException(
                message: 'no route',
                isConnectionError: true,
              ).toFailure()
              as TransportFailure;

      // Only this is a normal condition in an offline-first app.
      expect(failure.isOffline, isTrue);
    });

    test('take precedence over any status code', () {
      final failure = const HttpException(
        message: 'no route',
        statusCode: 500,
        isConnectionError: true,
      ).toFailure();

      expect(failure, isA<TransportFailure>());
      expect((failure as TransportFailure).isOffline, isTrue);
    });
  });

  group('validation details', () {
    test('lifts field errors out of an errors object', () {
      final failure =
          const HttpException(
                message: 'Invalid',
                statusCode: 422,
                body: <String, Object?>{
                  'errors': <String, Object?>{
                    'identifier': <Object?>['is required'],
                  },
                },
              ).toFailure()
              as ValidationFailure;

      expect(failure.errorsFor('identifier'), <String>['is required']);
    });

    test('reads the details key the socket contract uses', () {
      final failure =
          const HttpException(
                message: 'Invalid',
                statusCode: 400,
                body: <String, Object?>{
                  'details': <String, Object?>{
                    'body': <Object?>['too long'],
                  },
                },
              ).toFailure()
              as ValidationFailure;

      expect(failure.errorsFor('body'), <String>['too long']);
    });

    test('coerces a bare string message into a list', () {
      final failure =
          const HttpException(
                message: 'Invalid',
                statusCode: 422,
                body: <String, Object?>{
                  'errors': <String, Object?>{'identifier': 'is required'},
                },
              ).toFailure()
              as ValidationFailure;

      expect(failure.errorsFor('identifier'), <String>['is required']);
    });

    test('tolerates a body with no errors object', () {
      final failure =
          const HttpException(
                message: 'Invalid',
                statusCode: 422,
                body: <String, Object?>{'message': 'Invalid'},
              ).toFailure()
              as ValidationFailure;

      expect(failure.fieldErrors, isEmpty);
    });

    test('tolerates a non-map body', () {
      final failure =
          const HttpException(
                message: 'Invalid',
                statusCode: 422,
                body: 'plain text',
              ).toFailure()
              as ValidationFailure;

      expect(failure.fieldErrors, isEmpty);
    });
  });

  group('containment', () {
    test('the mapped failure is never the infrastructure type', () {
      // Rule 27: nothing above the data layer should be able to catch this.
      final failure = const HttpException(
        message: 'x',
        statusCode: 500,
      ).toFailure();

      expect(failure, isA<AppFailure>());
      expect(failure, isNot(isA<HttpException>()));
    });
  });
}
