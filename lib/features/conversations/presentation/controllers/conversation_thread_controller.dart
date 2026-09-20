import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';
import '../../application/coordinators/conversation_presence_coordinator.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/value_objects/outbound_media.dart';
import '../../realtime/message_events.dart';

part 'conversation_thread_controller.g.dart';

/// How many messages a thread shows before the reader asks for more.
///
/// One page: what `message:list` answers with, and what the local read is
/// capped at, so the two stay in step.
const int threadPageSize = 50;

/// How many of a thread's local messages the screen reads.
///
/// The local read is capped so a thread with ten thousand cached rows does not
/// become a ten-thousand-row query because somebody opened it. The cap grows
/// by a page each time the reader reaches the top, which is also when the
/// server is asked for the page above -- so history already on the device
/// shows without a connection, and history that is not gets fetched.
@riverpod
class ThreadWindow extends _$ThreadWindow {
  @override
  int build(String conversationId) => threadPageSize;

  void grow() => state += threadPageSize;
}

/// One thread's messages, from local storage.
///
/// Family-scoped by conversation id so two threads never share a subscription.
/// Like the rail, this is a database read: an incoming socket message reaches
/// the screen because the handler wrote a row, not because the widget is
/// listening to a socket.
@riverpod
Stream<List<Message>> threadMessages(Ref ref, String conversationId) {
  final int limit = ref.watch(threadWindowProvider(conversationId));

  return ref
      .watch(messageServiceProvider)
      .watchThread(conversationId, limit: limit);
}

/// The conversation being viewed.
@riverpod
Stream<Conversation?> threadConversation(Ref ref, String conversationId) {
  return ref
      .watch(conversationRepositoryProvider)
      .watchConversation(conversationId);
}

/// How long a typing bubble lives when the server named no expiry, and the
/// range any expiry it *did* name is held to.
///
/// The frame that clears a bubble is the one most likely to be lost -- a
/// locked phone, a dropped provider session -- so the reader expires it rather
/// than waiting to be told. A bubble that never goes away is worse than no
/// bubble: it says somebody is still there ten minutes after they left.
const Duration typingFallbackLife = Duration(seconds: 8);
const Duration typingShortestLife = Duration(seconds: 1);
const Duration typingLongestLife = Duration(seconds: 30);

/// Whether the customer is typing in this thread.
///
/// The one piece of thread state that does not come from the database, and
/// deliberately: it is true for a few seconds and then it is not, so storing
/// it would be a write per keystroke for something nothing may read again.
/// The realtime handler publishes it instead, and this expires it.
///
/// **The customer only**, which is what the web Inbox shows. A colleague
/// typing arrives on the same event under a different shape -- see
/// [TypingChanged] -- and is ignored here rather than silently rendered as
/// the customer.
@riverpod
class ThreadTyping extends _$ThreadTyping {
  Timer? _expiry;

  @override
  bool build(String conversationId) {
    final StreamSubscription<MessageRealtimeEvent> subscription = ref
        .watch(conversationSocketHandlerProvider)
        .transientEvents
        .listen((MessageRealtimeEvent event) => _apply(event, conversationId));

    ref.onDispose(() {
      _expiry?.cancel();
      _expiry = null;
      unawaited(subscription.cancel());
    });

    return false;
  }

  void _apply(MessageRealtimeEvent event, String conversationId) {
    if (event is! TypingChanged) return;
    if (event.conversationId != conversationId || !event.isCustomer) return;

    _expiry?.cancel();
    _expiry = null;

    if (!event.isTyping) {
      state = false;

      return;
    }

    state = true;
    _expiry = Timer(_lifeOf(event.expiresAt), () => state = false);
  }

  static Duration _lifeOf(DateTime? expiresAt) {
    if (expiresAt == null) return typingFallbackLife;

    final Duration remaining = expiresAt.difference(DateTime.now().toUtc());

    if (remaining < typingShortestLife) return typingShortestLife;
    if (remaining > typingLongestLife) return typingLongestLife;

    return remaining;
  }
}

/// Why the composer's last action did not go through.
///
/// A reason, not a sentence. The words are the screen's to choose, in the
/// member's language; a controller that held English sentences put English on
/// an Arabic screen.
enum ComposerError {
  /// The server or the rules refused this message.
  refused,

  /// No connection. The message is queued and will go when there is one.
  offline,

  /// The device could not store it.
  notSaved,

  /// Anything else.
  unknown,
}

/// The reason for [failure], as the composer reports it.
ComposerError composerErrorFor(AppFailure failure) => switch (failure) {
  ConflictFailure() || ValidationFailure() => ComposerError.refused,
  TransportFailure(isOffline: true) || SocketFailure() => ComposerError.offline,
  DatabaseFailure() => ComposerError.notSaved,
  _ => ComposerError.unknown,
};

/// The composer's state.
final class ComposerState {
  const ComposerState({this.isSending = false, this.error});

  /// True only while `compose` is writing the row. It is *not* "waiting for
  /// the server": the message is durable the moment the row exists, and the
  /// outbox takes it from there.
  final bool isSending;

  final ComposerError? error;

  ComposerState copyWith({
    bool? isSending,
    ComposerError? error,
    bool clearError = false,
  }) {
    return ComposerState(
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComposerState &&
      other.isSending == isSending &&
      other.error == error;

  @override
  int get hashCode => Object.hash(isSending, error);
}

/// Owns the thread screen's actions.
///
/// It does not hold the message list. The list lives in the database and is
/// read through [threadMessagesProvider] -- keeping a second copy here is how
/// an optimistic message and its acknowledged twin end up on screen together.
@riverpod
class ConversationThreadController extends _$ConversationThreadController {
  /// How often the customer is told somebody is typing, at most.
  ///
  /// The same twelve seconds the web Inbox uses. The provider's own bubble
  /// lasts around twenty-five, so this refreshes it comfortably inside its
  /// life without putting a frame on the wire per keystroke.
  static const Duration typingThrottle = Duration(seconds: 12);

  /// How long a single spell of typing keeps refreshing the bubble.
  ///
  /// The composer reports typing when the field stops being empty and again
  /// when it becomes empty, not on every keystroke -- so without a refresh a
  /// long reply loses its bubble a third of the way through. Bounded rather
  /// than endless: if the "stopped" report is ever missed, the customer sees
  /// a bubble for two minutes, not for the rest of the day.
  static const Duration typingMaximumSpell = Duration(minutes: 2);

  Timer? _typingRefresh;
  DateTime? _typingSentAt;

  /// The newest message this thread has already reported as read.
  String? _readThrough;

  /// The generated base exposes `conversationId` from this parameter, so the
  /// argument is available to every method below without being stored again.
  @override
  ComposerState build(String conversationId) {
    // Taking the seat in the thread's room, which is what makes delivery
    // ticks, attachments, withdrawals and typing arrive at all. Released when
    // the screen that is watching this controller goes away.
    final ConversationPresenceCoordinator presence = ref.read(
      conversationPresenceProvider,
    );

    unawaited(presence.enter(conversationId));

    // A message landing in a thread the member is looking at has been read, in
    // the only sense the word has here. The web Inbox does the same on the
    // newest message changing.
    ref.listen(threadMessagesProvider(conversationId), (
      AsyncValue<List<Message>>? previous,
      AsyncValue<List<Message>> next,
    ) {
      final String? newest = next.value?.lastOrNull?.id;

      if (newest == null || newest == _readThrough) return;

      final bool wasShowing = _readThrough != null;
      _readThrough = newest;

      // Not on the first load: `loadInitial` reports that one, and reporting
      // it twice would send a receipt for a thread that was merely restored
      // from cache behind a lock screen.
      if (wasShowing) unawaited(_markRead());
    });

    ref.onDispose(() {
      _typingRefresh?.cancel();
      _typingRefresh = null;
      unawaited(presence.leave(conversationId));
    });

    return const ComposerState();
  }

  /// Tells the customer somebody is typing.
  ///
  /// Called by the composer when the field stops being empty and again when it
  /// empties. Throttled, because the command exists to refresh a bubble the
  /// provider expires on its own -- there is nothing to send for "stopped".
  void notifyTyping(bool isTyping) {
    if (!isTyping) {
      _typingRefresh?.cancel();
      _typingRefresh = null;
      _typingSentAt = null;

      return;
    }

    _emitTyping();

    _typingRefresh ??= Timer.periodic(typingThrottle, (Timer timer) {
      if (timer.tick * typingThrottle.inMilliseconds >=
          typingMaximumSpell.inMilliseconds) {
        timer.cancel();
        _typingRefresh = null;

        return;
      }

      _emitTyping();
    });
  }

  /// Sends the ping unless one went recently.
  ///
  /// The refresh timer and a fresh spell of typing can both ask within the
  /// same second -- the member sends a reply and immediately starts the next
  /// one -- and the server rate-limits this command.
  void _emitTyping() {
    final DateTime now = DateTime.now();
    final DateTime? last = _typingSentAt;

    if (last != null && now.difference(last) < typingThrottle) return;

    _typingSentAt = now;

    ref.read(conversationRepositoryProvider).notifyTyping(conversationId);
  }

  /// Reports the thread as read, and never complains.
  ///
  /// The thread is open in front of the member: an error about a read receipt
  /// tells them something they can do nothing with, and the next sync
  /// reconciles the count from the server, which is authoritative for it.
  Future<void> _markRead() async {
    try {
      final Conversation? conversation = await ref
          .read(conversationRepositoryProvider)
          .findConversation(conversationId);

      if (conversation == null) return;

      await ref.read(conversationServiceProvider).markRead(conversation);
    } on AppFailure {
      // Deliberately silent -- see above.
    }
  }

  /// Sends a message.
  ///
  /// Returns immediately once the row and its outbox entry are written -- the
  /// bubble appears at once, in `pending`, and the outbox delivers it whenever
  /// the connection allows. Offline is not a special case here; it is the
  /// normal path with a longer wait.
  Future<bool> send(String body) => sendDraft(AppComposerDraft(text: body));

  Future<bool> sendDraft(AppComposerDraft draft) async {
    if (state.isSending) return false;

    if (draft.attachments.isNotEmpty) {
      final attachment = draft.attachments.first;
      final String? path = attachment.localPath;

      if (path == null || path.isEmpty) return false;

      return _sendMedia(
        type: messageTypeFromMime(attachment.mimeType),
        localPath: path,
        filename: attachment.name ?? 'attachment',
        mimeType: attachment.mimeType ?? 'application/octet-stream',
        caption: draft.text,
      );
    }

    return _sendText(draft.text);
  }

  Future<bool> sendVoice(String localPath) {
    return _sendMedia(
      type: 'audio',
      localPath: localPath,
      filename: 'voice.m4a',
      mimeType: 'audio/mp4',
    );
  }

  Future<bool> _sendText(String body) async {
    if (state.isSending) return false;

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .findConversation(conversationId);

      final session = ref.read(sessionCapabilityProvider);

      await ref
          .read(messageServiceProvider)
          .compose(
            conversation: conversation,
            rawBody: body,
            authorId: session.currentUserId,
            authorName: session.currentSession?.user.name,
          );

      state = state.copyWith(isSending: false);

      await ref.read(outboxCoordinatorProvider).drain();

      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isSending: false,
        error: composerErrorFor(failure),
      );

      return false;
    }
  }

  Future<bool> _sendMedia({
    required String type,
    required String localPath,
    required String filename,
    required String mimeType,
    String? caption,
  }) async {
    if (state.isSending) return false;

    state = state.copyWith(isSending: true, clearError: true);

    try {
      final conversation = await ref
          .read(conversationRepositoryProvider)
          .findConversation(conversationId);

      final session = ref.read(sessionCapabilityProvider);

      await ref
          .read(messageServiceProvider)
          .composeMedia(
            conversation: conversation,
            type: type,
            localPath: localPath,
            filename: filename,
            mimeType: mimeType,
            rawCaption: caption,
            authorId: session.currentUserId,
            authorName: session.currentSession?.user.name,
          );

      state = state.copyWith(isSending: false);

      await ref.read(outboxCoordinatorProvider).drain();

      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isSending: false,
        error: composerErrorFor(failure),
      );

      return false;
    }
  }

  /// Retries a failed message, reusing its original idempotency key.
  Future<void> retry(Message message) async {
    final key = message.clientMessageId ?? message.id;

    try {
      await ref.read(outboxCoordinatorProvider).retry(key);
    } on AppFailure catch (failure) {
      state = state.copyWith(error: composerErrorFor(failure));
    }
  }

  /// Throws away a message that never reached the server.
  Future<void> discard(Message message) async {
    final key = message.clientMessageId ?? message.id;

    await ref.read(outboxCoordinatorProvider).discard(key);
  }

  /// True while a page of history is on its way. A scroll listener fires on
  /// every frame near the top; one request at a time is the whole point.
  bool _loadingOlder = false;

  /// True once the server answered a history request with nothing, which is
  /// what the beginning of a thread looks like. Asked again only if the
  /// controller is rebuilt.
  bool _reachedStart = false;

  /// Whether a history request is in flight. For the screen's tests.
  bool get isLoadingOlder => _loadingOlder;

  /// Whether the thread's beginning has been reached. For the screen's tests.
  bool get hasReachedStart => _reachedStart;

  /// Loads the page of history above what the screen shows.
  ///
  /// Called by the screen when the reader reaches the top. Two things happen,
  /// in this order: the server is asked for the page before the oldest message
  /// on screen, and the local window widens by a page. The order matters
  /// offline -- a failed fetch still widens the window, so history the device
  /// already holds is shown without a connection, which is what local-first
  /// promises.
  ///
  /// The screen reads the database, so it updates when this lands rather than
  /// through a return value.
  Future<void> loadOlder() async {
    if (_loadingOlder) return;

    final List<Message>? held = ref
        .read(threadMessagesProvider(conversationId))
        .value;

    if (held == null || held.isEmpty) return;

    // A window the local read fills to the brim may have more behind it; one
    // it does not fill has shown everything the device holds.
    final bool localHasMore =
        held.length >= ref.read(threadWindowProvider(conversationId));

    if (_reachedStart && !localHasMore) return;

    _loadingOlder = true;
    bool reveal = localHasMore;

    try {
      if (!_reachedStart) {
        // Oldest first is reading order, so the top of the thread is the head.
        final int written = await ref
            .read(messageRepositoryProvider)
            .loadOlder(
              conversationId: conversationId,
              before: held.first.createdAt,
              limit: threadPageSize,
            );

        if (written == 0) {
          _reachedStart = true;
        } else {
          reveal = true;
        }
      }
    } on AppFailure catch (failure) {
      _reportHistoryFailure(failure);
    } finally {
      _loadingOlder = false;

      if (reveal) {
        ref.read(threadWindowProvider(conversationId).notifier).grow();
      }
    }
  }

  void clearError() {
    if (state.error == null) return;

    state = state.copyWith(clearError: true);
  }

  /// Catches the thread up when the screen opens.
  ///
  /// Asks for the newest page and writes it locally; the screen's database
  /// read shows it. Cached messages are on screen before this returns, so a
  /// slow or absent connection costs the reader nothing they already had.
  Future<void> loadInitial() async {
    try {
      await ref
          .read(messageRepositoryProvider)
          .loadLatest(conversationId: conversationId, limit: threadPageSize);
    } on AppFailure catch (failure) {
      _reportHistoryFailure(failure);
    }

    // After the page, not before: opening a thread whose newest messages have
    // not arrived yet and declaring it read is how an unread message is
    // cleared without ever being shown. Outside the `try` because a history
    // read that failed does not change what the member is looking at.
    await _markRead();
  }

  /// Offline is not a failure of a history read: what the device holds is
  /// what it shows, and the thread catches up on reconnect through sync. The
  /// composer's copy for it says a message will be sent later, which would
  /// be the wrong sentence on a screen that was only opened. Anything else is
  /// reported as the composer would.
  void _reportHistoryFailure(AppFailure failure) {
    final ComposerError error = composerErrorFor(failure);

    if (error == ComposerError.offline) return;

    state = state.copyWith(error: error);
  }
}
