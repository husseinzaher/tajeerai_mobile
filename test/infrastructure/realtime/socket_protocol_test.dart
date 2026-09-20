import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/infrastructure/realtime/serialization/event_codec.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_command.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_event.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_exception.dart';

import '../../support/fixed_clock.dart';

void main() {
  group('SocketAck', () {
    test('reads a successful envelope', () {
      final ack = SocketAck.fromWire(<String, Object?>{
        'ok': true,
        'data': <String, Object?>{'messageId': 'm1'},
      });

      expect(ack, isA<SocketAckSuccess>());
      expect((ack as SocketAckSuccess).data['messageId'], 'm1');
    });

    test('reads an acknowledgement with no body', () {
      final ack = SocketAck.fromWire(<String, Object?>{'ok': true});

      expect(ack, isA<SocketAckSuccess>());
      expect((ack as SocketAckSuccess).data, isEmpty);
    });

    test('keeps a list payload reachable', () {
      final ack = SocketAck.fromWire(<String, Object?>{
        'ok': true,
        'data': <Object?>[1, 2],
      });

      expect((ack as SocketAckSuccess).rawData, <Object?>[1, 2]);
    });

    test('reads a rejection with its code and message', () {
      final ack = SocketAck.fromWire(<String, Object?>{
        'ok': false,
        'error': <String, Object?>{
          'code': 'CONFLICT',
          'message': 'Already archived.',
        },
      });

      expect(ack, isA<SocketAckFailure>());
      expect((ack as SocketAckFailure).code, 'CONFLICT');
      expect(ack.message, 'Already archived.');
    });

    test('reads field-level validation details', () {
      final ack = SocketAck.fromWire(<String, Object?>{
        'ok': false,
        'error': <String, Object?>{
          'code': 'VALIDATION_FAILED',
          'message': 'Invalid.',
          'details': <String, Object?>{
            'body': <Object?>['too long'],
          },
        },
      });

      expect((ack as SocketAckFailure).details!['body'], <String>['too long']);
    });

    test('treats a non-object reply as a failure, never a success', () {
      // A client that reads a broken frame as `ok` corrupts its own database.
      final ack = SocketAck.fromWire('nonsense');

      expect(ack, isA<SocketAckFailure>());
      expect((ack as SocketAckFailure).code, 'INTERNAL_ERROR');
    });

    test('treats a malformed error object as a failure', () {
      final ack = SocketAck.fromWire(<String, Object?>{
        'ok': false,
        'error': 'not an object',
      });

      expect(ack, isA<SocketAckFailure>());
    });

    test('treats a null reply as a failure', () {
      expect(SocketAck.fromWire(null), isA<SocketAckFailure>());
    });
  });

  group('SocketEvent', () {
    test('reads the envelope the backend puts on every broadcast', () {
      final event = SocketEvent.fromWire('message.created', <String, Object?>{
        'eventId': 'e1',
        'occurredAt': testEpoch.toIso8601String(),
        'conversationId': 'c1',
      });

      expect(event.name, 'message.created');
      expect(event.eventId, 'e1');
      expect(event.occurredAt, testEpoch);
      expect(event.isDeduplicable, isTrue);
    });

    test('normalises the timestamp to UTC', () {
      final event = SocketEvent.fromWire('x', <String, Object?>{
        'occurredAt': '2026-03-01T14:00:00+02:00',
        'eventId': 'e1',
      });

      expect(event.occurredAt!.isUtc, isTrue);
      expect(event.occurredAt, DateTime.utc(2026, 3, 1, 12));
    });

    test('reports a frame with no envelope as not deduplicable', () {
      // Typing carries no envelope: there is nothing to deduplicate and
      // nothing to order.
      final event = SocketEvent.fromWire(
        'conversation.typing',
        <String, Object?>{'conversationId': 'c1'},
      );

      expect(event.isDeduplicable, isFalse);
      expect(event.eventId, isNull);
    });

    test('survives a non-map payload', () {
      final event = SocketEvent.fromWire('x', 'unexpected');

      expect(event.payload, isEmpty);
      expect(event.isDeduplicable, isFalse);
    });

    test('ignores an unparseable timestamp rather than throwing', () {
      final event = SocketEvent.fromWire('x', <String, Object?>{
        'eventId': 'e1',
        'occurredAt': 'not a date',
      });

      expect(event.occurredAt, isNull);
      expect(event.isDeduplicable, isFalse);
    });
  });

  group('SocketCommand', () {
    test('carries a name and a payload', () {
      const command = SocketCommand(
        name: 'message:send',
        payload: <String, Object?>{'body': 'hi'},
      );

      expect(command.name, 'message:send');
      expect(command.payload['body'], 'hi');
    });

    test('defaults to an empty payload', () {
      const command = SocketCommand(name: 'conversation:list');

      expect(command.payload, isEmpty);
    });
  });

  group('SocketException', () {
    test('maps each server rejection onto the failure taxonomy', () {
      expect(
        const SocketException(
          message: 'x',
          code: 'UNAUTHENTICATED',
        ).toFailure(),
        isA<AuthenticationFailure>(),
      );
      expect(
        const SocketException(message: 'x', code: 'FORBIDDEN').toFailure(),
        isA<AuthorizationFailure>(),
      );
      expect(
        const SocketException(message: 'x', code: 'NOT_FOUND').toFailure(),
        isA<NotFoundFailure>(),
      );
      expect(
        const SocketException(message: 'x', code: 'CONFLICT').toFailure(),
        isA<ConflictFailure>(),
      );
      expect(
        const SocketException(
          message: 'x',
          code: 'VALIDATION_FAILED',
        ).toFailure(),
        isA<ValidationFailure>(),
      );
      expect(
        const SocketException(message: 'x', code: 'RATE_LIMITED').toFailure(),
        isA<SocketFailure>(),
      );
    });

    test('carries validation details across the boundary', () {
      final failure =
          const SocketException(
                message: 'Invalid.',
                code: 'VALIDATION_FAILED',
                details: <String, List<String>>{
                  'body': <String>['too long'],
                },
              ).toFailure()
              as ValidationFailure;

      expect(failure.errorsFor('body'), <String>['too long']);
    });

    test('marks the four permanent rejections as not retryable', () {
      for (final code in <String>[
        'VALIDATION_FAILED',
        'FORBIDDEN',
        'NOT_FOUND',
        'CONFLICT',
      ]) {
        expect(
          SocketException(message: 'x', code: code).isRetryable,
          isFalse,
          reason: '$code should not be retried -- the server would repeat it',
        );
      }
    });

    test('marks transport problems as retryable', () {
      for (final code in <String?>[
        'TIMEOUT',
        'DISCONNECTED',
        'UPSTREAM_UNAVAILABLE',
        'RATE_LIMITED',
        'INTERNAL_ERROR',
        null,
      ]) {
        expect(
          SocketException(message: 'x', code: code).isRetryable,
          isTrue,
          reason: '$code should be retried',
        );
      }
    });

    test('a timeout names the command that timed out', () {
      const exception = SocketException.timeout('message:send');

      expect(exception.code, 'TIMEOUT');
      expect(exception.message, contains('message:send'));
      expect(exception.isRetryable, isTrue);
    });

    test('a disconnected send is retryable', () {
      const exception = SocketException.disconnected('message:send');

      expect(exception.code, 'DISCONNECTED');
      expect(exception.isRetryable, isTrue);
    });
  });

  group('EventCodec', () {
    const codec = EventCodec();

    test('recognises the two frames that precede a server close', () {
      expect(codec.isLifecycleEvent('auth.expired'), isTrue);
      expect(codec.isLifecycleEvent('access.changed'), isTrue);
    });

    test('recognises Socket.IO transport frames', () {
      for (final name in <String>['connect', 'disconnect', 'ping', 'error']) {
        expect(codec.isLifecycleEvent(name), isTrue);
      }
    });

    test('treats business events as forwardable', () {
      expect(codec.isLifecycleEvent('message.created'), isFalse);
      expect(codec.isLifecycleEvent('conversation.updated'), isFalse);
    });

    test('reads the reason off a lifecycle payload', () {
      expect(
        codec.reasonOf(<String, Object?>{'reason': 'unauthenticated'}),
        'unauthenticated',
      );
      expect(codec.reasonOf('nonsense'), isNull);
      expect(codec.reasonOf(null), isNull);
    });
  });
}
