import 'dart:async';

import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/domain/repositories/conversation_repository.dart';

/// An in-memory [ConversationRepository].
///
/// Hand-written rather than mocked: these tests assert on *behaviour* -- what
/// the service does with what it is given -- and a hand-written fake states
/// the contract's semantics once, where a mock would restate them in every
/// test as a stub.
class FakeConversationRepository implements ConversationRepository {
  final StreamController<List<Conversation>> _controller =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, Conversation> _conversations = <String, Conversation>{};

  final List<String> markedRead = <String>[];
  final List<Conversation> upserted = <Conversation>[];

  String? lastSearchTerm;
  bool? lastIncludeArchived;
  int syncListCalls = 0;
  DateTime? lastSyncSince;

  /// Set to make the next synchronisation fail.
  AppFailure? failureToThrow;

  /// What the next sync reports back.
  SyncOutcome? nextSyncOutcome;

  void emit(List<Conversation> conversations) {
    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }

    _controller.add(conversations);
  }

  void seed(List<Conversation> conversations) {
    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }
  }

  @override
  Stream<List<Conversation>> watchConversations({
    bool includeArchived = false,
    String? searchTerm,
    int limit = 50,
  }) {
    lastSearchTerm = searchTerm;
    lastIncludeArchived = includeArchived;

    return _controller.stream;
  }

  @override
  Stream<Conversation?> watchConversation(String conversationId) {
    return _controller.stream.map((_) => _conversations[conversationId]);
  }

  @override
  Future<Conversation?> findConversation(String conversationId) async =>
      _conversations[conversationId];

  @override
  Future<int> synchronizeList({int limit = 25, String? cursor}) async {
    syncListCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return _conversations.length;
  }

  @override
  Future<SyncOutcome> synchronizeSince(
    DateTime since, {
    String? conversationId,
  }) async {
    lastSyncSince = since;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return nextSyncOutcome ??
        SyncOutcome(
          conversationsWritten: 0,
          messagesWritten: 0,
          syncedAt: since.add(const Duration(minutes: 1)),
        );
  }

  @override
  Future<void> upsertAll(
    List<Conversation> conversations, {
    DateTime? eventAt,
  }) async {
    upserted.addAll(conversations);

    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }

    _controller.add(_conversations.values.toList(growable: false));
  }

  @override
  Future<void> markRead(String conversationId) async {
    markedRead.add(conversationId);

    final existing = _conversations[conversationId];

    if (existing != null) {
      _conversations[conversationId] = existing.copyWith(unreadCount: 0);
    }
  }

  @override
  Future<void> clear() async {
    _conversations.clear();
  }

  Future<void> dispose() => _controller.close();
}
