import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

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

/// The composer's state.
final class ComposerState {
  const ComposerState({this.isSending = false, this.errorMessage});

  /// True only while `compose` is writing the row. It is *not* "waiting for
  /// the server": the message is durable the moment the row exists, and the
  /// outbox takes it from there.
  final bool isSending;

  final String? errorMessage;

  ComposerState copyWith({
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ComposerState(
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ComposerState &&
      other.isSending == isSending &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(isSending, errorMessage);
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
  Future<bool> send(String body) async {
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

      // Nudge the queue. It would drain on its own on the next reconnect;
      // doing it now is what makes a message sent while online leave
      // immediately rather than on a timer.
      await ref.read(outboxCoordinatorProvider).drain();

      return true;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        isSending: false,
        errorMessage: _messageFor(failure),
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
      state = state.copyWith(errorMessage: _messageFor(failure));
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
      state = state.copyWith(errorMessage: _messageFor(failure));
    }
  }

  void clearError() {
    if (state.errorMessage == null) return;

    state = state.copyWith(clearError: true);
  }

  static String _messageFor(AppFailure failure) {
    return switch (failure) {
      ConflictFailure(:final message) => message,
      ValidationFailure() => 'That message could not be sent.',
      TransportFailure(isOffline: true) || SocketFailure() =>
        'You are offline. The message will send when you reconnect.',
      DatabaseFailure() => 'The message could not be saved on this device.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
