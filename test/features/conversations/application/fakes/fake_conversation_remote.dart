import 'dart:math';

import 'package:TajeerAi/features/conversations/data/remote/conversation_remote_data_source.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/infrastructure/realtime/socket_manager.dart';

/// A [ConversationRemoteDataSource] that never touches a socket.
///
/// Subclassed rather than reimplemented from an interface, because the real
/// class is concrete: extracting an interface for it would be an abstraction
/// created only to satisfy a test, which the architecture explicitly warns
/// against. Every socket-touching method is overridden, so the inherited
/// [SocketManager] is never used.
class FakeConversationRemote extends ConversationRemoteDataSource {
  FakeConversationRemote() : super(_unusedSocket);

  /// Never called: every method that would reach it is overridden below.
  static final SocketManager _unusedSocket = _NullSocketManager();

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

/// Stands in for the socket the fake never uses.
class _NullSocketManager implements SocketManager {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('FakeConversationRemote must not reach the socket.');
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
