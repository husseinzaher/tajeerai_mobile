import '../entities/conversation.dart';
import '../repositories/conversation_repository.dart';

/// Business rules about conversations.
///
/// Framework-free: no Flutter, no Riverpod, no socket, no database. Every rule
/// below is exercised in `test/features/conversations/domain/` against a fake
/// repository and nothing else.
class ConversationService {
  const ConversationService(this._repository);

  final ConversationRepository _repository;

  /// The rail, ordered the way the product wants it.
  ///
  /// Sorting is a business decision, not a query detail: pinned threads come
  /// first because the operator pinned them, and everything else is ordered by
  /// most recent activity. Doing it here rather than in SQL means the same
  /// order applies to a locally-inserted optimistic row that has not been
  /// through the database's ordering yet.
  Stream<List<Conversation>> watchInbox({
    bool includeArchived = false,
    String? searchTerm,
  }) {
    return _repository
        .watchConversations(
          includeArchived: includeArchived,
          searchTerm: searchTerm,
        )
        .map(sortForInbox);
  }

  /// Pinned first, then newest activity first.
  ///
  /// A thread with no activity at all sorts by creation, so a freshly started
  /// conversation does not sink to the bottom of the list before its first
  /// message lands.
  static List<Conversation> sortForInbox(List<Conversation> conversations) {
    final sorted = <Conversation>[...conversations];

    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;

      return bTime.compareTo(aTime);
    });

    return sorted;
  }

  /// Whether a message may be sent into [conversation].
  ///
  /// **"Archived conversations cannot receive new messages."** Archiving is
  /// the workspace's decision that a thread is finished; a message into one
  /// would revive a conversation nobody is watching. A `closed` thread is
  /// deliberately still writable -- the backend reopens it on a new message.
  ///
  /// A null conversation is also refused: the thread is not in local storage,
  /// so nothing here can vouch for its state.
  SendEligibility canSendTo(Conversation? conversation) {
    if (conversation == null) return SendEligibility.unknownConversation;

    if (!conversation.acceptsNewMessages) return SendEligibility.archived;

    return SendEligibility.allowed;
  }

  /// Total unread threads, for the app badge.
  ///
  /// Counts *threads*, not messages, matching the backend's `UnreadSummary`,
  /// whose `total` is "conversations with at least one unread message".
  static int unreadThreadCount(List<Conversation> conversations) {
    return conversations.where((conversation) => conversation.hasUnread).length;
  }

  /// Marks a thread read.
  ///
  /// A no-op when there is nothing unread: the command would be a wasted round
  /// trip, and on a flaky connection an outbox entry that achieves nothing.
  Future<void> markRead(Conversation conversation) async {
    if (!conversation.hasUnread) return;

    await _repository.markRead(conversation.id);
  }

  Future<Conversation?> find(String conversationId) =>
      _repository.findConversation(conversationId);
}

/// Whether a send is permitted, and why not when it is not.
enum SendEligibility {
  allowed,

  /// The thread is archived and closed to new traffic.
  archived,

  /// The thread is not in local storage, so its state is unknown.
  unknownConversation;

  bool get isAllowed => this == SendEligibility.allowed;
}
