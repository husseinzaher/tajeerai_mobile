import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/value_objects/outbound_media.dart';

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
  /// The generated base exposes `conversationId` from this parameter, so the
  /// argument is available to every method below without being stored again.
  @override
  ComposerState build(String conversationId) => const ComposerState();

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
