import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/conversation_presence_coordinator.dart';
import 'package:TajeerAi/features/conversations/presentation/controllers/conversation_thread_controller.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

import '../../../support/fixed_clock.dart';
import '../application/fakes/fake_conversation_remote.dart';
import '../domain/fakes/fake_conversation_repository.dart';
import '../domain/fakes/fake_message_repository.dart';

const String _id = 'c1';

Conversation _conversation({int unreadCount = 0}) => Conversation(
  id: _id,
  state: ConversationState.open,
  unreadCount: unreadCount,
  createdAt: testEpoch,
);

Message _message(int index) => Message(
  id: 'm$index',
  conversationId: _id,
  direction: MessageDirection.inbound,
  state: MessageState.read,
  body: 'Message $index',
  createdAt: testEpoch.add(Duration(minutes: index)),
);

/// Oldest first, which is how [threadMessagesProvider] hands them over.
List<Message> _thread(int count) => List<Message>.generate(count, _message);

/// The thread's catch-up and history, driven directly.
///
/// The screen is faked out and the repository is faked in: what is under test
/// is the controller's own decisions -- when to ask the server for history,
/// when to stop, and how wide the local read is allowed to be.
void main() {
  late FakeMessageRepository repository;
  late FakeConversationRepository conversations;
  late FakeConversationRemote remote;
  late StreamController<List<Message>> messages;
  late ProviderContainer container;

  setUp(() {
    repository = FakeMessageRepository();
    conversations = FakeConversationRepository();
    remote = FakeConversationRemote();
    messages = StreamController<List<Message>>.broadcast();

    container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(repository),
        conversationRepositoryProvider.overrideWithValue(conversations),
        // The seat in the conversation's room. Faked rather than left out:
        // the controller takes it in `build`, so a container without it is a
        // controller that cannot be created at all.
        conversationPresenceProvider.overrideWithValue(
          ConversationPresenceCoordinator(
            remote: remote,
            logger: Logger('test', verbose: false),
          ),
        ),
        threadMessagesProvider(_id).overrideWith((Ref ref) => messages.stream),
      ],
    );

    // Everything here is auto-disposed. The screen keeps these alive by
    // watching them; a test has to do the same or a window grown by the
    // controller is thrown away with the provider that held it.
    container.listen(threadMessagesProvider(_id), (_, _) {});
    container.listen(threadWindowProvider(_id), (_, _) {});
    container.listen(conversationThreadControllerProvider(_id), (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await messages.close();
  });

  ConversationThreadController controller() =>
      container.read(conversationThreadControllerProvider(_id).notifier);

  ComposerState state() =>
      container.read(conversationThreadControllerProvider(_id));

  int window() => container.read(threadWindowProvider(_id));

  Future<void> show(List<Message> thread) async {
    messages.add(thread);
    // Lets the stream deliver and the provider take the value.
    await Future<void>.delayed(Duration.zero);
  }

  group('loadInitial', () {
    test('asks for the newest page once', () async {
      await controller().loadInitial();

      expect(repository.loadLatestCalls, 1);
      expect(state().error, isNull);
    });

    test('being offline is not an error worth a sentence', () async {
      repository.failureToThrow = const TransportFailure(
        message: 'no route',
        isOffline: true,
      );

      await controller().loadInitial();

      expect(state().error, isNull);
    });

    test('anything else is reported', () async {
      repository.failureToThrow = const UnknownFailure();

      await controller().loadInitial();

      expect(state().error, ComposerError.unknown);
    });
  });

  group('loadOlder', () {
    test('with nothing on screen there is nothing to ask above', () async {
      await show(<Message>[]);

      await controller().loadOlder();

      expect(repository.loadOlderCalls, 0);
      expect(window(), threadPageSize);
    });

    test(
      'asks for the page before the oldest shown and widens the window',
      () async {
        await show(_thread(3));
        repository.loadOlderResult = 12;

        await controller().loadOlder();

        expect(repository.loadOlderBefore, <DateTime>[_message(0).createdAt]);
        expect(window(), threadPageSize * 2);
        expect(state().error, isNull);
      },
    );

    test('a scroll that fires twice asks the server once', () async {
      await show(_thread(3));
      repository.loadOlderResult = 12;
      repository.loadOlderGate = Completer<void>();

      final Future<void> first = controller().loadOlder();
      final Future<void> second = controller().loadOlder();

      expect(controller().isLoadingOlder, isTrue);

      repository.loadOlderGate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.loadOlderCalls, 1);
      expect(window(), threadPageSize * 2);
    });

    test('stops asking once the server has nothing older', () async {
      await show(_thread(3));
      repository.loadOlderResult = 0;

      await controller().loadOlder();
      await controller().loadOlder();

      expect(repository.loadOlderCalls, 1);
      expect(controller().hasReachedStart, isTrue);
      // Three messages do not fill a window of fifty: the device holds
      // nothing more either, so there is nothing to widen for.
      expect(window(), threadPageSize);
    });

    test('a full window still widens at the start of history, to show what is cached', () async {
      await show(_thread(threadPageSize));
      repository.loadOlderResult = 0;

      await controller().loadOlder();

      expect(window(), threadPageSize * 2);

      // The next page reveals what the device held; the server is not
      // asked again, and a window that was not filled widens no further.
      await show(_thread(threadPageSize + 5));
      await controller().loadOlder();

      expect(repository.loadOlderCalls, 1);
      expect(window(), threadPageSize * 2);
    });

    test('offline, cached history is still shown', () async {
      await show(_thread(threadPageSize));
      repository.failureToThrow = const TransportFailure(
        message: 'no route',
        isOffline: true,
      );

      await controller().loadOlder();

      expect(window(), threadPageSize * 2);
      expect(state().error, isNull);
      // The server was not reached, so its start is not known.
      expect(controller().hasReachedStart, isFalse);
    });

    test(
      'a failure that is not offline is reported, and leaves the window',
      () async {
        await show(_thread(3));
        repository.failureToThrow = const UnknownFailure();

        await controller().loadOlder();

        expect(state().error, ComposerError.unknown);
        expect(window(), threadPageSize);
        expect(controller().isLoadingOlder, isFalse);
      },
    );
  });

  group('the seat in the conversation room', () {
    test('is taken as soon as the controller exists', () async {
      // Not on `loadInitial`: delivery ticks, attachments, withdrawals and
      // typing are broadcast to the room and nowhere else, so a thread that
      // never joins is half-live from the moment it opens.
      controller();

      await pumpEventQueue();

      expect(remote.joined, <String>[_id]);
    });

    test('is given up when the screen watching it goes away', () async {
      controller();
      await pumpEventQueue();

      container.dispose();
      await pumpEventQueue();

      expect(remote.left, <String>[_id]);
    });
  });

  group('read receipts', () {
    test('the newest page being in is what marks the thread read', () async {
      conversations.seed(<Conversation>[_conversation(unreadCount: 3)]);

      await controller().loadInitial();

      expect(conversations.markedRead, <String>[_id]);
    });

    test('a thread with nothing unread is not reported', () async {
      conversations.seed(<Conversation>[_conversation()]);

      await controller().loadInitial();

      expect(conversations.markedRead, isEmpty);
    });

    test(
      'a failed history read still does not report a phantom read',
      () async {
        conversations.seed(<Conversation>[_conversation(unreadCount: 3)]);
        repository.failureToThrow = const UnknownFailure();

        await controller().loadInitial();

        // The member is looking at the thread either way -- what failed was the
        // catch-up, not the screen.
        expect(conversations.markedRead, <String>[_id]);
      },
    );

    test('a message arriving in an open thread is read', () async {
      conversations.seed(<Conversation>[_conversation(unreadCount: 1)]);
      controller();

      await show(_thread(2));
      conversations.seed(<Conversation>[_conversation(unreadCount: 1)]);
      await show(_thread(3));
      await pumpEventQueue();

      // The first emission is the thread being restored from cache and is not
      // a receipt; the second is a message landing in front of the member.
      expect(conversations.markedRead, <String>[_id]);
    });

    test('a read receipt that fails is never shown to the member', () async {
      conversations.seed(<Conversation>[_conversation(unreadCount: 3)]);
      conversations.failureToThrow = const UnknownFailure();

      await controller().loadInitial();

      expect(state().error, isNull);
    });
  });

  group('telling the customer somebody is typing', () {
    test('writing sends one ping, and writing more does not', () async {
      controller()
        ..notifyTyping(true)
        ..notifyTyping(true);

      // The provider's bubble lasts around twenty-five seconds; a frame per
      // report would be a frame per burst of keystrokes, and the server rate
      // limits the command.
      expect(conversations.typingPings, <String>[_id]);
    });

    test('emptying the field sends nothing at all', () async {
      controller().notifyTyping(false);

      // There is no "stopped typing" to send -- the bubble expires by itself.
      expect(conversations.typingPings, isEmpty);
    });
  });
}
