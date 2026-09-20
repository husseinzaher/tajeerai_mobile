import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/services/conversation_service.dart';

import '../../../support/fixed_clock.dart';
import 'fakes/fake_conversation_repository.dart';

Conversation _conversation({
  required String id,
  ConversationState state = ConversationState.open,
  bool isArchived = false,
  bool isPinned = false,
  int unreadCount = 0,
  DateTime? lastMessageAt,
  DateTime? createdAt,
}) {
  return Conversation(
    id: id,
    state: state,
    isArchived: isArchived,
    isPinned: isPinned,
    unreadCount: unreadCount,
    lastMessageAt: lastMessageAt,
    createdAt: createdAt ?? testEpoch,
  );
}

void main() {
  late FakeConversationRepository repository;
  late ConversationService service;

  setUp(() {
    repository = FakeConversationRepository();
    service = ConversationService(repository);
  });

  group('the archived rule', () {
    test('archived conversations cannot receive new messages', () {
      final archived = _conversation(id: 'c1', isArchived: true);

      expect(archived.acceptsNewMessages, isFalse);
      expect(service.canSendTo(archived), SendEligibility.archived);
    });

    test('a conversation in the archived state cannot receive messages', () {
      // Archiving is expressed two ways by the backend -- a flag on the row
      // and a lifecycle state -- and both must close the thread to traffic.
      final archived = _conversation(
        id: 'c1',
        state: ConversationState.archived,
      );

      expect(service.canSendTo(archived), SendEligibility.archived);
    });

    test('open conversations accept new messages', () {
      expect(
        service.canSendTo(_conversation(id: 'c1')),
        SendEligibility.allowed,
      );
    });

    test('closed conversations still accept messages', () {
      // Deliberately allowed: the backend reopens a closed thread on a new
      // message, so refusing here would break a supported flow.
      final closed = _conversation(id: 'c1', state: ConversationState.closed);

      expect(service.canSendTo(closed), SendEligibility.allowed);
    });

    test('an unknown conversation is refused', () {
      // Nothing local can vouch for its state, so sending would be a guess.
      expect(service.canSendTo(null), SendEligibility.unknownConversation);
    });
  });

  group('inbox ordering', () {
    test('pinned conversations come first', () {
      final sorted = ConversationService.sortForInbox(<Conversation>[
        _conversation(
          id: 'recent',
          lastMessageAt: testEpoch.add(const Duration(hours: 5)),
        ),
        _conversation(id: 'pinned', isPinned: true, lastMessageAt: testEpoch),
      ]);

      expect(sorted.map((c) => c.id), <String>['pinned', 'recent']);
    });

    test('unpinned conversations sort by most recent activity', () {
      final sorted = ConversationService.sortForInbox(<Conversation>[
        _conversation(id: 'old', lastMessageAt: testEpoch),
        _conversation(
          id: 'new',
          lastMessageAt: testEpoch.add(const Duration(hours: 2)),
        ),
        _conversation(
          id: 'middle',
          lastMessageAt: testEpoch.add(const Duration(hours: 1)),
        ),
      ]);

      expect(sorted.map((c) => c.id), <String>['new', 'middle', 'old']);
    });

    test('a conversation with no messages sorts by creation time', () {
      // A freshly started thread must not sink below older ones before its
      // first message lands.
      final sorted = ConversationService.sortForInbox(<Conversation>[
        _conversation(id: 'withMessage', lastMessageAt: testEpoch),
        _conversation(
          id: 'brandNew',
          createdAt: testEpoch.add(const Duration(hours: 1)),
        ),
      ]);

      expect(sorted.first.id, 'brandNew');
    });

    test('does not mutate the list it was given', () {
      final original = <Conversation>[
        _conversation(id: 'a', lastMessageAt: testEpoch),
        _conversation(
          id: 'b',
          lastMessageAt: testEpoch.add(const Duration(hours: 1)),
        ),
      ];

      ConversationService.sortForInbox(original);

      expect(original.map((c) => c.id), <String>['a', 'b']);
    });

    test('handles an empty inbox', () {
      expect(ConversationService.sortForInbox(<Conversation>[]), isEmpty);
    });
  });

  group('unread counting', () {
    test('counts threads, not messages', () {
      // Matches the backend's UnreadSummary, whose total is "conversations
      // with at least one unread message".
      final count = ConversationService.unreadThreadCount(<Conversation>[
        _conversation(id: 'a', unreadCount: 5),
        _conversation(id: 'b', unreadCount: 1),
        _conversation(id: 'c'),
      ]);

      expect(count, 2);
    });

    test('is zero for an empty inbox', () {
      expect(ConversationService.unreadThreadCount(<Conversation>[]), 0);
    });
  });

  group('markRead', () {
    test('marks a thread with unread messages', () async {
      await service.markRead(_conversation(id: 'c1', unreadCount: 3));

      expect(repository.markedRead, <String>['c1']);
    });

    test('does nothing when there is nothing unread', () async {
      // The command would be a wasted round trip, and on a flaky connection an
      // outbox entry that achieves nothing.
      await service.markRead(_conversation(id: 'c1'));

      expect(repository.markedRead, isEmpty);
    });
  });

  group('watchInbox', () {
    test('emits the repository stream, sorted', () async {
      // Subscribe before emitting: the fake's stream is a broadcast, like the
      // database's, so an event published before anyone listens is dropped.
      final result = service.watchInbox().first;

      repository.emit(<Conversation>[
        _conversation(id: 'old', lastMessageAt: testEpoch),
        _conversation(id: 'pinned', isPinned: true),
      ]);

      expect((await result).first.id, 'pinned');
    });

    test('passes the search term through to the repository', () async {
      final result = service.watchInbox(searchTerm: 'ada').first;

      repository.emit(<Conversation>[]);
      await result;

      expect(repository.lastSearchTerm, 'ada');
    });
  });
}
