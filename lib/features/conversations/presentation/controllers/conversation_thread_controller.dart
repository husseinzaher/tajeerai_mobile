import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/value_objects/outbound_media.dart';

part 'conversation_thread_controller.g.dart';

/// One thread's messages, from local storage.
///
/// Family-scoped by conversation id so two threads never share a subscription.
/// Like the rail, this is a database read: an incoming socket message reaches
/// the screen because the handler wrote a row, not because the widget is
/// listening to a socket.
@riverpod
Stream<List<Message>> threadMessages(Ref ref, String conversationId) {
  return ref.watch(messageServiceProvider).watchThread(conversationId);
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

  /// Loads older history from the server into local storage.
  ///
  /// The screen reads the database, so it updates when this lands rather than
  /// through a return value.
  Future<void> loadOlder(DateTime before) async {
    try {
      await ref
          .read(messageRepositoryProvider)
          .loadOlder(conversationId: conversationId, before: before);
    } on AppFailure catch (failure) {
      state = state.copyWith(error: composerErrorFor(failure));
    }
  }

  void clearError() {
    if (state.error == null) return;

    state = state.copyWith(clearError: true);
  }

  Future<void> loadInitial() async {
    try {
      await ref
          .read(messageRepositoryProvider)
          .loadLatest(conversationId: conversationId); // ← محتاجة تتعمل
    } on AppFailure catch (failure) {
      state = state.copyWith(error: composerErrorFor(failure));
    }
  }
}
