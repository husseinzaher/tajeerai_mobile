import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/network/token_refresher.dart';
import 'package:TajeerAi/infrastructure/realtime/connection/connection_state.dart';
import 'package:TajeerAi/infrastructure/realtime/connection/reconnect_policy.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_command.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_event.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_exception.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_manager.dart';

import 'fakes/fake_socket_client.dart';

/// A policy with negligible delays, so reconnection is observable without the
/// test waiting on a real backoff.
const _fastPolicy = ReconnectPolicy(
  initialDelay: Duration(milliseconds: 1),
  maxDelay: Duration(milliseconds: 2),
);

void main() {
  late FakeSocketClient client;
  late FakeCredentials credentials;
  late SocketManager manager;

  setUp(() {
    client = FakeSocketClient();
    credentials = FakeCredentials();

    manager = SocketManager(
      client: client,
      credentials: credentials,
      logger: Logger('test', verbose: false),
      policy: _fastPolicy,
    );
  });

  tearDown(() => manager.dispose());

  group('connection', () {
    test('connects with the current credential', () async {
      await manager.start();

      expect(client.connectTokens, <String>['token-1']);
      expect(manager.state, SocketConnectionState.connected);
    });

    test('publishes connecting then connected', () async {
      final states = <SocketConnectionState>[];
      final subscription = manager.states.listen(states.add);

      await manager.start();
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        states,
        containsAllInOrder(<SocketConnectionState>[
          SocketConnectionState.connecting,
          SocketConnectionState.connected,
        ]),
      );
    });

    test('announces the connection so features can resynchronise', () async {
      var announced = 0;
      final subscription = manager.connections.listen((_) => announced += 1);

      await manager.start();
      await pumpEventQueue();
      await subscription.cancel();

      // Emitted on the first connection too: a client that has been closed has
      // missed events whether or not it was ever connected before.
      expect(announced, 1);
    });

    test('stays closed and reports unauthenticated with no session', () async {
      credentials.token = null;

      await manager.start();

      expect(client.connectTokens, isEmpty);
      expect(manager.state, SocketConnectionState.unauthenticated);
    });

    test('starting twice does not open a second socket', () async {
      await manager.start();
      await manager.start();

      expect(client.connectTokens, hasLength(1));
    });

    /*
      Signing in is exactly this sequence. The app starts the manager when the
      session appears, and before that there is no token -- so a `start` that
      refused to look again would leave the socket closed for the whole run,
      and the Inbox empty behind a "showing saved messages" banner until the
      process was restarted. `unauthenticated` is documented as terminal *until
      a new token arrives*, which is what this is.
    */
    test('opens once a session exists, having started without one', () async {
      credentials.token = null;
      await manager.start();

      expect(client.connectTokens, isEmpty);
      expect(manager.state, SocketConnectionState.unauthenticated);

      credentials.token = 'token-1';
      await manager.start();

      expect(client.connectTokens, <String>['token-1']);
      expect(manager.state, SocketConnectionState.connected);
    });
  });

  group('reconnection', () {
    test('reconnects after an unclean drop', () async {
      await manager.start();

      // Collect the sequence rather than sampling `state`: the test policy
      // backs off in milliseconds, so the transient `reconnecting` state can
      // be gone before an assertion runs. The sequence is what matters
      // anyway -- the UI renders it.
      final states = <SocketConnectionState>[];
      final subscription = manager.states.listen(states.add);

      client.drop();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await subscription.cancel();

      expect(
        states,
        containsAllInOrder(<SocketConnectionState>[
          SocketConnectionState.reconnecting,
          SocketConnectionState.connected,
        ]),
      );
      expect(client.connectTokens.length, greaterThan(1));
    });

    test('does not reconnect after a deliberate close', () async {
      await manager.start();

      client.drop(wasClean: true);
      await pumpEventQueue();

      expect(manager.state, SocketConnectionState.disconnected);
    });

    test('does not reconnect after stop', () async {
      await manager.start();
      await manager.stop();

      client.drop();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Clearing "wanted" first is what stops a drop arriving mid-teardown
      // scheduling a reconnect for a session that no longer exists.
      expect(client.connectTokens, hasLength(1));
      expect(manager.state, SocketConnectionState.disconnected);
    });

    test('retries after a failed connection attempt', () async {
      client.connectFailure = const SocketException(
        message: 'refused',
        code: 'TIMEOUT',
      );

      final states = <SocketConnectionState>[];
      final subscription = manager.states.listen(states.add);

      await manager.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await subscription.cancel();

      expect(states, contains(SocketConnectionState.reconnecting));
      expect(manager.state, SocketConnectionState.connected);
    });

    test('announces every reconnection, not only the first', () async {
      var announced = 0;
      final subscription = manager.connections.listen((_) => announced += 1);

      await manager.start();
      client.drop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await subscription.cancel();

      expect(announced, greaterThanOrEqualTo(2));
    });
  });

  group('credential recovery', () {
    test('refreshes the credential when the server rejects it', () async {
      await manager.start();

      client.rejectCredential();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(credentials.refreshCalls, 1);

      // Reconnects with the *new* token, which is the whole point --
      // reconnecting with the rejected one loops against the same refusal.
      expect(client.connectTokens.last, 'token-2');
    });

    test('stops when the session is refused', () async {
      credentials.outcome = const RefreshRejected();

      await manager.start();

      client.rejectCredential();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Terminal rather than a retry loop; the auth feature takes over by
      // watching for this state.
      expect(manager.state, SocketConnectionState.unauthenticated);
      expect(client.connectTokens, hasLength(1));
    });

    test('does not treat an access change as a credential problem', () async {
      await manager.start();

      client.changeAccess();
      await pumpEventQueue();

      // The server drops the socket next; the disconnect handler schedules the
      // reconnect that recomputes the rooms.
      expect(credentials.refreshCalls, 0);
    });

    test('keeps trying when the renewal could not be asked', () async {
      credentials.outcome = const RefreshUnavailable();

      await manager.start();

      client.rejectCredential();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Offline or throttled says nothing about the session. The socket stays
      // wanted and tries again instead of reporting the member signed out --
      // which is what this used to do on a dead network.
      expect(manager.state, isNot(SocketConnectionState.unauthenticated));
      expect(client.connectTokens.length, greaterThan(1));
    });

    test(
      'passes an access change on, so the session can be read again',
      () async {
        await manager.start();
        final Future<void> announced = manager.accessChanges.first;

        client.changeAccess();

        await expectLater(announced, completes);
      },
    );

    test('a transport error alone does not tear down the connection', () async {
      await manager.start();

      client.reportError(StateError('transient'));
      await pumpEventQueue();

      // Socket.IO reports errors that do not close the connection; only a
      // disconnect schedules a retry.
      expect(manager.state, SocketConnectionState.connected);
    });
  });

  group('commands', () {
    test('sends over a live socket', () async {
      await manager.start();

      await manager.send(const SocketCommand(name: 'conversation:list'));

      expect(client.sentCommands.single.name, 'conversation:list');
    });

    test('fails fast rather than queueing when disconnected', () async {
      // Queueing here would be a second queue racing the outbox for the same
      // command.
      expect(
        () => manager.send(const SocketCommand(name: 'message:send')),
        throwsA(isA<SocketException>()),
      );

      expect(client.sentCommands, isEmpty);
    });

    test('drops a fire-and-forget emit when disconnected', () async {
      manager.emit(const SocketCommand(name: 'conversation:typing-indicator'));

      // Correct for something transient: a lost typing frame is invisible.
      expect(client.emittedCommands, isEmpty);
    });

    test('emits a transient signal over a live socket', () async {
      await manager.start();

      manager.emit(const SocketCommand(name: 'conversation:typing-indicator'));

      expect(client.emittedCommands, hasLength(1));
    });
  });

  group('event forwarding', () {
    test('passes frames through untouched', () async {
      await manager.start();

      final received = <SocketEvent>[];
      final subscription = manager.events.listen(received.add);

      client.pushEvent(
        SocketEvent.fromWire('message.created', <String, Object?>{
          'eventId': 'e1',
        }),
      );

      await pumpEventQueue();
      await subscription.cancel();

      // The manager interprets no business event -- that is the feature
      // handler's job.
      expect(received.single.name, 'message.created');
      expect(received.single.eventId, 'e1');
    });
  });

  group('teardown', () {
    test('stop disconnects and reports disconnected', () async {
      await manager.start();
      await manager.stop();

      expect(client.disconnectCalls, greaterThanOrEqualTo(1));
      expect(manager.state, SocketConnectionState.disconnected);
    });
  });
}
