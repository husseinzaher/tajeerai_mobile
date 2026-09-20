import 'dart:async';

import '../../../infrastructure/database/daos/sync_dao.dart';
import '../../../infrastructure/logging/logger.dart';
import '../../../infrastructure/realtime/socket_event.dart';
import '../data/models/conversation_dto.dart';
import '../data/models/message_dto.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/message.dart';
import '../domain/repositories/conversation_repository.dart';
import '../domain/repositories/message_repository.dart';
import 'conversation_events.dart';
import 'message_events.dart';

/// Turns realtime frames into local state.
///
/// **This is the only place a socket event becomes a database write.** The UI
/// never sees a frame; it watches the database, which this writes to. That
/// indirection is the whole realtime-first architecture, and it is what makes
/// "a message arrived" and "a message was loaded from cache" the same event as
/// far as any screen is concerned.
///
/// It owns four guarantees, each of which is a bug if dropped:
///
/// 1. **Deduplication.** A reconnect replays events the client already has.
///    Every frame carrying an `eventId` is registered in `processed_events`
///    first, and a repeat is skipped -- otherwise an unread count double-counts.
/// 2. **Ordering.** `occurredAt` is passed down to the write, which refuses to
///    overwrite a row holding a newer stamp. A late broadcast cannot undo
///    newer state.
/// 3. **Isolation.** One malformed frame is logged and dropped; it never takes
///    down the subscription and never stops later frames arriving.
/// 4. **Silence.** Payload contents are never logged -- these carry customer
///    messages.
class ConversationSocketHandler {
  ConversationSocketHandler({
    required ConversationRepository conversations,
    required MessageRepository messages,
    required SyncDao syncDao,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
  }) : _conversations = conversations,
       _messages = messages,
       _syncDao = syncDao,
       _logger = logger,
       _clock = clock;

  final ConversationRepository _conversations;
  final MessageRepository _messages;
  final SyncDao _syncDao;
  final Logger _logger;
  final DateTime Function() _clock;

  StreamSubscription<SocketEvent>? _subscription;

  final StreamController<MessageRealtimeEvent> _typing =
      StreamController<MessageRealtimeEvent>.broadcast();

  /// Transient signals the UI may show but that are never stored.
  ///
  /// Typing is the only one. It is published as a stream rather than written
  /// to the database because persisting something that expires in three
  /// seconds would be a write per keystroke, per agent.
  Stream<MessageRealtimeEvent> get transientEvents => _typing.stream;

  /// Subscribes to the transport.
  void attach(Stream<SocketEvent> events) {
    _subscription ??= events.listen(
      (event) => unawaited(handle(event)),
      onError: (Object error, StackTrace stackTrace) {
        _logger.error(
          'realtime stream error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Processes one frame.
  ///
  /// Public so the whole pipeline is testable by handing it a [SocketEvent] --
  /// no socket, no server, no timing.
  ///
  /// Returns true when the frame changed local state, which is what the
  /// deduplication and ordering tests assert on.
  Future<bool> handle(SocketEvent event) async {
    if (!ConversationRealtimeEvents.handled.contains(event.name)) return false;

    // Typing is exempt from deduplication: it carries no envelope, and two
    // identical frames a second apart both mean "still typing".
    if (event.name == ConversationRealtimeEvents.typing) {
      return _handleTyping(event);
    }

    if (!await _claim(event)) return false;

    try {
      return await _apply(event);
    } on FormatException catch (error) {
      // A malformed frame is dropped, not retried: the server will not send a
      // better version of it, and throwing would kill the subscription.
      _logger.warning(
        'dropped malformed realtime frame',
        data: <String, Object?>{'event': event.name},
      );
      _logger.debug(
        'frame decode failed',
        data: <String, Object?>{'reason': error.message},
      );

      return false;
    } on Object catch (error, stackTrace) {
      _logger.error(
        'failed to apply realtime frame',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{'event': event.name},
      );

      return false;
    }
  }

  /// Registers the event, returning false when it has already been applied.
  ///
  /// A frame without an `eventId` cannot be deduplicated, so it is allowed
  /// through -- the ordering guard on the write is what protects the row in
  /// that case.
  Future<bool> _claim(SocketEvent event) async {
    final eventId = event.eventId;

    if (eventId == null) return true;

    final isNew = await _syncDao.registerEvent(
      eventId: eventId,
      eventName: event.name,
      now: _clock(),
    );

    if (!isNew) {
      _logger.debug(
        'skipped duplicate event',
        data: <String, Object?>{'event': event.name},
      );
    }

    return isNew;
  }

  Future<bool> _apply(SocketEvent event) async {
    final occurredAt = event.occurredAt;

    switch (event.name) {
      case ConversationRealtimeEvents.messageCreated:
      case ConversationRealtimeEvents.messageUpdated:
        final message = MessageDto.decodeEvent(event.payload);
        final written = await _messages.upsertAll(<Message>[
          message,
        ], eventAt: occurredAt);

        return written > 0;

      case ConversationRealtimeEvents.messageRemoved:
        final messageId = event.payload['messageId']?.toString();

        if (messageId == null) {
          throw const FormatException('messageRemoved carried no message id.');
        }

        await _messages.remove(messageId);

        return true;

      case ConversationRealtimeEvents.mediaReady:
        final messageId = event.payload['messageId']?.toString();
        final mediaUrl = event.payload['mediaUrl']?.toString();
        final type = event.payload['type']?.toString();

        if (messageId == null || mediaUrl == null || mediaUrl.isEmpty) {
          throw const FormatException('mediaReady was incomplete.');
        }

        await _messages.updateMedia(
          messageId: messageId,
          mediaUrl: mediaUrl,
          type: type,
          eventAt: occurredAt,
        );

        return true;

      case ConversationRealtimeEvents.conversationCreated:
      case ConversationRealtimeEvents.conversationUpdated:
      case ConversationRealtimeEvents.conversationStateChanged:
        final conversation = ConversationDto.decodeEvent(event.payload);
        await _conversations.upsertAll(<Conversation>[
          conversation,
        ], eventAt: occurredAt);

        return true;

      case ConversationRealtimeEvents.unreadUpdated:
        return _applyUnread(event);

      default:
        return false;
    }
  }

  /// Applies `conversation.unread-updated`.
  ///
  /// The count is taken from the event verbatim rather than incremented
  /// locally. The server is authoritative -- another agent reading the thread
  /// on a different device changes this number, and a client that counts its
  /// own drifts within minutes.
  Future<bool> _applyUnread(SocketEvent event) async {
    final conversationId = event.payload['conversationId']?.toString();
    final unreadCount = event.payload['unreadCount'];

    if (conversationId == null || unreadCount is! int) {
      throw const FormatException('unreadUpdated carried no count.');
    }

    final existing = await _conversations.findConversation(conversationId);

    // An event for a thread this device has never seen is not an error: the
    // conversation simply has not synced yet, and the sync will carry the
    // current count with it.
    if (existing == null) return false;

    await _conversations.upsertAll(<Conversation>[
      existing.copyWith(unreadCount: unreadCount),
    ], eventAt: event.occurredAt);

    return true;
  }

  /// Decodes `conversation.typing`, in either of the two shapes it arrives in.
  ///
  /// A member's own typing is relayed by the gateway as `isTyping`; the
  /// customer's is reported by the provider as `typing`, with an `actor` and an
  /// expiry. Reading only the first is how a customer's bubble decoded as
  /// "stopped typing" and never appeared.
  bool _handleTyping(SocketEvent event) {
    final conversationId = event.payload['conversationId']?.toString();

    if (conversationId == null) return false;

    final Object? agentTyping = event.payload['isTyping'];
    final Object? customerTyping = event.payload['typing'];

    if (!_typing.isClosed) {
      _typing.add(
        TypingChanged(
          conversationId: conversationId,
          isTyping: agentTyping == true || customerTyping == true,
          userId: event.payload['userId']?.toString(),
          actor: event.payload['actor']?.toString(),
          expiresAt: DateTime.tryParse(
            event.payload['expiresAt']?.toString() ?? '',
          )?.toUtc(),
        ),
      );
    }

    return true;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _typing.close();
  }
}
