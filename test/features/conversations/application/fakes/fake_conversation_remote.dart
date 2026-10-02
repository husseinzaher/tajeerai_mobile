import 'dart:math';

import 'package:TajeerAi/features/conversations/application/ports/conversation_remote_port.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';

/// A [ConversationRemotePort] that never touches a socket.
///
/// Implements the application port directly: the coordinators and the
/// repositories depend on the port and not on the socket adapter, which is
/// what lets every outbox and sync test run without a transport behind it.
class FakeConversationRemote implements ConversationRemotePort {
  final List<MessageSendResult> sentMessages = <MessageSendResult>[];
  final List<String> attemptedClientMessageIds = <String>[];
  final List<String> markedRead = <String>[];

  int sendAttempts = 0;
  int syncCalls = 0;
  int listCalls = 0;

  /// Thrown by the next call. Already an `AppFailure`, matching what the real
  /// data source does at its translation boundary.
  Object? failureToThrow;

  String nextMessageId = 'server-1';
  bool nextDeduplicated = false;
  String? lastSendType;
  String? lastMediaId;
  String? lastSendBody;

  List<Conversation> nextConversations = const <Conversation>[];
  List<Message> nextMessages = const <Message>[];
  DateTime? nextSyncedAt;

  @override
  Future<MessageSendResult> sendMessage({
    required String conversationId,
    required String clientMessageId,
    String type = 'text',
    String? body,
    String? mediaId,
    String? filename,
    String? mimeType,
  }) async {
    sendAttempts += 1;
    attemptedClientMessageIds.add(clientMessageId);
    lastSendType = type;
    lastMediaId = mediaId;
    lastSendBody = body;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    final result = MessageSendResult(
      clientMessageId: clientMessageId,
      messageId: nextMessageId,
      deduplicated: nextDeduplicated,
    );

    sentMessages.add(result);

    return result;
  }

  /// Not modelled: nothing under test opens a thread through the port.
  @override
  Future<ConversationWithMessages> openConversation(
    String conversationId, {
    int messageLimit = 50,
  }) => throw StateError('FakeConversationRemote does not model open.');

  @override
  Future<void> markRead(String conversationId) async {
    markedRead.add(conversationId);

    final failure = failureToThrow;

    if (failure != null) throw failure;
  }

  @override
  Future<ConversationPage> listConversations({
    int limit = 25,
    String? cursor,
    String? search,
    bool? archived,
  }) async {
    listCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return ConversationPage(conversations: nextConversations);
  }

  @override
  Future<RemoteSyncResult> synchronize({
    required DateTime since,
    String? conversationId,
  }) async {
    syncCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return RemoteSyncResult(
      conversations: nextConversations,
      messages: nextMessages,
      syncedAt: nextSyncedAt ?? since.add(const Duration(minutes: 1)),
    );
  }

  /// The cursor each `message:list` carried, in call order. Null is a request
  /// for the newest page.
  final List<DateTime?> listedBefore = <DateTime?>[];

  @override
  Future<MessagePage> listMessages({
    required String conversationId,
    DateTime? before,
    int limit = 50,
  }) async {
    listedBefore.add(before);

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return MessagePage(messages: nextMessages);
  }

  @override
  void sendTypingIndicator({required String conversationId}) {
    typingPings.add(conversationId);
  }

  /// Every `conversation:typing-indicator` sent, in call order.
  final List<String> typingPings = <String>[];

  /// Seats taken and given up, in call order.
  final List<String> joined = <String>[];
  final List<String> left = <String>[];

  /// Message ids discarded on the server, in call order.
  final List<String> discarded = <String>[];

  @override
  Future<void> discardMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final failure = failureToThrow;

    if (failure != null) throw failure;

    discarded.add(messageId);
  }

  @override
  Future<void> joinConversation(String conversationId) async {
    joined.add(conversationId);

    final failure = failureToThrow;

    if (failure != null) throw failure;
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    left.add(conversationId);

    final failure = failureToThrow;

    if (failure != null) throw failure;
  }
}

/// A [Random] with a fixed seed, so jittered backoff is reproducible.
///
/// The backoff is genuinely random in production -- that is the point, it
/// spreads a reconnecting herd -- so a test that asserted on an exact delay
/// would be flaky. Seeding keeps the behaviour while making it repeatable.
class SeededRandom implements Random {
  SeededRandom([int seed = 42]) : _delegate = Random(seed);

  final Random _delegate;

  @override
  bool nextBool() => _delegate.nextBool();

  @override
  double nextDouble() => _delegate.nextDouble();

  @override
  int nextInt(int max) => _delegate.nextInt(max);
}
