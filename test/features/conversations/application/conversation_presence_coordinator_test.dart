import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/conversation_presence_coordinator.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

import 'fakes/fake_conversation_remote.dart';

/// The member's seat in an open thread.
///
/// What is under test is not "does it send a join" but the two things that
/// were actually wrong: that a seat survives a reconnection, and that failing
/// to take one is never allowed to reach the member.
void main() {
  late FakeConversationRemote remote;
  late StreamController<void> connections;
  late ConversationPresenceCoordinator presence;

  setUp(() {
    remote = FakeConversationRemote();
    connections = StreamController<void>.broadcast();
    presence = ConversationPresenceCoordinator(
      remote: remote,
      logger: Logger('test', verbose: false),
    );
  });

  tearDown(() async {
    await presence.dispose();
    await connections.close();
  });

  test('entering takes the seat', () async {
    await presence.enter('c1');

    expect(remote.joined, <String>['c1']);
    expect(presence.occupied, <String>{'c1'});
  });

  test('leaving gives it up', () async {
    await presence.enter('c1');
    await presence.leave('c1');

    expect(remote.left, <String>['c1']);
    expect(presence.occupied, isEmpty);
  });

  test('leaving a thread never entered sends nothing', () async {
    await presence.leave('c1');

    expect(remote.left, isEmpty);
  });

  test('a reconnection retakes every seat', () async {
    presence.bindTo(connections.stream);

    await presence.enter('c1');
    await presence.enter('c2');

    connections.add(null);
    await pumpEventQueue();

    /*
      The point of the whole coordinator. A reconnected socket comes back with
      the rooms the member's grants allow, which never includes the thread they
      happen to be reading -- so without this replay a thread that outlived a
      tunnel keeps receiving new messages and silently stops receiving delivery
      ticks, attachments and typing.
    */
    expect(remote.joined, <String>['c1', 'c2', 'c1', 'c2']);
  });

  test('a reconnection after leaving does not retake the seat', () async {
    presence.bindTo(connections.stream);

    await presence.enter('c1');
    await presence.leave('c1');

    connections.add(null);
    await pumpEventQueue();

    expect(remote.joined, <String>['c1']);
  });

  test('a refused join is swallowed, and retried on the next connection', () async {
    presence.bindTo(connections.stream);
    remote.failureToThrow = const TransportFailure(
      message: 'No connection.',
      isOffline: true,
    );

    // Never thrown at the caller: the thread still shows everything the device
    // holds, and an error about a room is not something a member can act on.
    await presence.enter('c1');

    expect(remote.joined, <String>['c1']);
    expect(presence.occupied, <String>{'c1'});

    remote.failureToThrow = null;
    connections.add(null);
    await pumpEventQueue();

    // Remembered despite failing, which is the case that matters: the usual
    // reason a join fails is that the connection was already going.
    expect(remote.joined, <String>['c1', 'c1']);
  });

  test('a failed leave still forgets the thread', () async {
    await presence.enter('c1');
    remote.failureToThrow = const TransportFailure(
      message: 'No connection.',
      isOffline: true,
    );

    await presence.leave('c1');

    expect(presence.occupied, isEmpty);
  });
}
