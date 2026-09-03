import '../../../../failures/app_failure.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';
import '../repositories/message_repository.dart';
import '../value_objects/message_content.dart';
import 'conversation_service.dart';

/// Business rules about messages.
///
/// Owns *whether* something may be sent and what a message means. It does not
/// own the send workflow -- persisting, dispatching the socket command,
/// handling the acknowledgement and retrying is a sequence, and sequences
/// belong to `application/coordinators/`.
class MessageService {
  const MessageService({
    required MessageRepository repository,
    required ConversationService conversationService,
    required String Function() idGenerator,
  }) : _repository = repository,
       _conversations = conversationService,
       _newId = idGenerator;

  final MessageRepository _repository;
  final ConversationService _conversations;

  /// Generates the idempotency key. Injected so tests are deterministic.
  final String Function() _newId;

  Stream<List<Message>> watchThread(String conversationId, {int limit = 50}) {
    return _repository
        .watchMessages(conversationId, limit: limit)
        .map(sortForThread);
  }

  /// Oldest first, which is reading order.
  ///
  /// Ties break on id so the order is *stable*: two messages sharing a
  /// timestamp -- which happens when a sync writes a page at once -- must not
  /// swap places between rebuilds and make the list jump under the reader.
  static List<Message> sortForThread(List<Message> messages) {
    final sorted = <Message>[...messages];

    sorted.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);

      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

    return sorted;
  }

  /// Validates and stores an outbound message.
  ///
  /// Throws [ValidationFailure] for content the rules refuse, and
  /// [ConflictFailure] when the thread will not take it -- both *before*
  /// anything is written, so a refused send leaves no row behind.
  ///
  /// On success the message exists locally in [MessageState.pending] and is
  /// queued in the outbox. It is durable from this moment: the app can be
  /// killed before the socket command goes out and the message still sends.
  Future<Message> compose({
    required Conversation? conversation,
    required String rawBody,
    String? authorId,
    String? authorName,
  }) async {
    final eligibility = _conversations.canSendTo(conversation);

    if (!eligibility.isAllowed) {
      throw ConflictFailure(
        message: switch (eligibility) {
          SendEligibility.archived =>
            'This conversation is archived and cannot receive new messages.',
          SendEligibility.unknownConversation =>
            'This conversation is not available.',
          SendEligibility.allowed => '',
        },
      );
    }

    final parsed = MessageContent.parse(rawBody);

    final content = switch (parsed) {
      ValidMessageContent(:final content) => content,
      InvalidMessageContent(:final error) => throw ValidationFailure(
        message: 'The message could not be sent.',
        fieldErrors: <String, List<String>>{
          'body': <String>[
            switch (error) {
              MessageContentError.empty => 'message.empty',
              MessageContentError.tooLong => 'message.tooLong',
            },
          ],
        },
      ),
    };

    return _repository.enqueueOutbound(
      conversationId: conversation!.id,
      content: content,
      clientMessageId: _newId(),
      authorId: authorId,
      authorName: authorName,
    );
  }

  /// Whether an incoming state is allowed to replace the one held.
  ///
  /// Delivery states only move forward. WhatsApp's receipts arrive out of
  /// order often enough that without this a `read` message flips back to
  /// `delivered` when the older receipt lands a moment later.
  ///
  /// A move to [MessageState.failed] is always allowed: a failure is current
  /// news whatever came before it.
  static bool canTransition(MessageState from, MessageState to) {
    if (from == to) return false;
    if (to == MessageState.failed) return true;
    if (to == MessageState.discarded) return true;

    return _rank(to) > _rank(from);
  }

  static int _rank(MessageState state) => switch (state) {
    MessageState.pending => 0,
    MessageState.sending => 1,
    MessageState.failed => 1,
    MessageState.sent => 2,
    MessageState.delivered => 3,
    MessageState.read => 4,
    MessageState.discarded => 5,
  };

  /// Marks a failed message ready to try again.
  ///
  /// Reuses the original [Message.clientMessageId] -- that is what makes the
  /// retry idempotent. Generating a fresh key here is how a retry turns into a
  /// duplicate message for the customer.
  Future<Message> prepareRetry(Message message) async {
    if (!message.state.canRetry) {
      throw ConflictFailure(
        message: 'This message is not in a state that can be retried.',
      );
    }

    await _repository.updateState(
      messageId: message.id,
      state: MessageState.pending,
      failureReason: null,
    );

    return message.copyWith(state: MessageState.pending);
  }

  /// Throws away a message the server never accepted.
  Future<void> discard(Message message) async {
    if (message.state.isConfirmed) {
      throw ConflictFailure(
        message: 'This message was already sent and cannot be discarded.',
      );
    }

    await _repository.remove(message.id);
  }
}
