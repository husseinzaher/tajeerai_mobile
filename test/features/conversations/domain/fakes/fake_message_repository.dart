import 'dart:async';

import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/domain/repositories/message_repository.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/message_content.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/outbound_media.dart';

/// Records a state update the service asked for.
class StateUpdate {
  const StateUpdate({
    required this.messageId,
    required this.state,
    this.failureReason,
    this.externalId,
  });

  final String messageId;
  final MessageState state;
  final String? failureReason;
  final String? externalId;
}

/// Records a media path the coordinator wrote back.
class MediaUpdate {
  const MediaUpdate({
    required this.messageId,
    this.mediaUrl,
    this.localMediaPath,
    this.type,
  });

  final String messageId;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? type;
}

/// Records a reconciliation.
class Reconciliation {
  const Reconciliation({
    required this.clientMessageId,
    required this.serverMessageId,
    required this.state,
  });

  final String clientMessageId;
  final String serverMessageId;
  final MessageState state;
}

/// An in-memory [MessageRepository].
class FakeMessageRepository implements MessageRepository {
  final StreamController<List<Message>> _controller =
      StreamController<List<Message>>.broadcast();

  final Map<String, Message> _messages = <String, Message>{};

  final List<Message> enqueued = <Message>[];
  final List<StateUpdate> stateUpdates = <StateUpdate>[];
  final List<Reconciliation> reconciliations = <Reconciliation>[];
  final List<MediaUpdate> mediaUpdates = <MediaUpdate>[];
  final List<String> removed = <String>[];
  final List<Message> upserted = <Message>[];

  /// The `eventAt` each upsert was given, so ordering behaviour is assertable.
  final List<DateTime?> upsertEventStamps = <DateTime?>[];

  int loadOlderCalls = 0;
  int loadLatestCalls = 0;
  Object? failureToThrow;

  void seed(List<Message> messages) {
    for (final message in messages) {
      _messages[message.id] = message;
    }
  }

  void emit(List<Message> messages) {
    seed(messages);
    _controller.add(messages);
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId, {int limit = 50}) {
    return _controller.stream;
  }

  @override
  Future<Message?> findMessage(String messageId) async => _messages[messageId];

  @override
  Future<Message?> findByClientMessageId(String clientMessageId) async {
    for (final message in _messages.values) {
      if (message.clientMessageId == clientMessageId) return message;
    }

    return null;
  }

  @override
  Future<Message> enqueueOutbound({
    required String conversationId,
    required MessageContent content,
    required String clientMessageId,
    String? authorId,
    String? authorName,
  }) async {
    final failure = failureToThrow;

    if (failure != null) throw failure;

    final message = Message(
      id: clientMessageId,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      direction: MessageDirection.outbound,
      state: MessageState.pending,
      body: content.value,
      authorId: authorId,
      authorName: authorName,
      createdAt: DateTime.utc(2026, 3, 1, 12),
    );

    enqueued.add(message);
    _messages[message.id] = message;

    return message;
  }

  @override
  Future<Message> enqueueOutboundMedia({
    required String conversationId,
    required OutboundMedia media,
    required String clientMessageId,
    String? authorId,
    String? authorName,
  }) async {
    final failure = failureToThrow;

    if (failure != null) throw failure;

    final message = Message(
      id: clientMessageId,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      direction: MessageDirection.outbound,
      state: MessageState.pending,
      type: media.type,
      body: media.caption,
      localMediaPath: media.localPath,
      authorId: authorId,
      authorName: authorName,
      createdAt: DateTime.utc(2026, 3, 1, 12),
    );

    enqueued.add(message);
    _messages[message.id] = message;

    return message;
  }

  @override
  Future<void> updateMedia({
    required String messageId,
    String? mediaUrl,
    String? localMediaPath,
    String? type,
    DateTime? eventAt,
  }) async {
    mediaUpdates.add(
      MediaUpdate(
        messageId: messageId,
        mediaUrl: mediaUrl,
        localMediaPath: localMediaPath,
        type: type,
      ),
    );

    final existing = _messages[messageId];

    if (existing == null) return;

    _messages[messageId] = existing.copyWith(
      mediaUrl: mediaUrl,
      localMediaPath: localMediaPath,
      type: type,
    );
  }

  @override
  Future<int> upsertAll(List<Message> messages, {DateTime? eventAt}) async {
    upserted.addAll(messages);
    upsertEventStamps.add(eventAt);
    seed(messages);
    _controller.add(_messages.values.toList(growable: false));

    return messages.length;
  }

  @override
  Future<void> updateState({
    required String messageId,
    required MessageState state,
    String? externalId,
    String? failureReason,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? eventAt,
  }) async {
    stateUpdates.add(
      StateUpdate(
        messageId: messageId,
        state: state,
        failureReason: failureReason,
        externalId: externalId,
      ),
    );

    final existing = _messages[messageId];

    if (existing != null) {
      _messages[messageId] = existing.copyWith(state: state);
    }
  }

  @override
  Future<void> reconcile({
    required String clientMessageId,
    required String serverMessageId,
    required MessageState state,
  }) async {
    reconciliations.add(
      Reconciliation(
        clientMessageId: clientMessageId,
        serverMessageId: serverMessageId,
        state: state,
      ),
    );

    final existing = _messages.remove(clientMessageId);

    if (existing != null) {
      _messages[serverMessageId] = existing.copyWith(
        id: serverMessageId,
        state: state,
      );
    }
  }

  /// The `before` each history request carried, oldest request first.
  final List<DateTime> loadOlderBefore = <DateTime>[];

  /// What the next history request reports as written. Zero is what the
  /// beginning of a thread answers with.
  int loadOlderResult = 0;

  /// Held open until a test completes it, so an in-flight history request
  /// can be observed. Null means requests complete at once.
  Completer<void>? loadOlderGate;

  @override
  Future<int> loadOlder({
    required String conversationId,
    required DateTime before,
    int limit = 50,
  }) async {
    loadOlderCalls += 1;
    loadOlderBefore.add(before);

    final Completer<void>? gate = loadOlderGate;

    if (gate != null) await gate.future;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return loadOlderResult;
  }

  /// Counted rather than ignored, since the thread's catch-up is worth
  /// asserting on.
  @override
  Future<int> loadLatest({
    required String conversationId,
    int limit = 50,
  }) async {
    loadLatestCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return 0;
  }

  @override
  Future<void> remove(String messageId) async {
    removed.add(messageId);
    _messages.remove(messageId);
  }

  Future<void> dispose() => _controller.close();
}
