import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../controllers/conversation_thread_controller.dart';
import '../widgets/async_view_state.dart';
import '../widgets/message_composer.dart';
import '../widgets/message_view_data.dart';

/// One conversation.
///
/// Reads its messages from the local database. A message arriving over the
/// socket appears here because the realtime handler wrote a row and the
/// reactive query re-emitted -- this screen has no socket subscription and no
/// message list of its own to keep in step.
///
/// The thread itself is the design system's `AppMessageTimeline`, drawn from
/// `message_view_data.dart`. The composer and the header move onto the design
/// system next.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final conversation = ref.watch(
      threadConversationProvider(widget.conversationId),
    );
    final messages = ref.watch(threadMessagesProvider(widget.conversationId));
    final composer = ref.watch(
      conversationThreadControllerProvider(widget.conversationId),
    );

    // Composer errors are transient notices, not a screen state -- the thread
    // behind them is still perfectly readable.
    ref.listen(conversationThreadControllerProvider(widget.conversationId), (
      previous,
      next,
    ) {
      final message = next.errorMessage;

      if (message == null || message == previous?.errorMessage) return;

      AppSnackbar.show(
        context,
        message: message,
        tone: AppSnackbarTone.warning,
      );

      ref
          .read(
            conversationThreadControllerProvider(widget.conversationId)
                .notifier,
          )
          .clearError();
    });

    final thread = conversation.value;

    return AppScaffold(
      showBack: true,
      onBack: () => context.pop(),
      titleWidget: thread == null ? null : _ThreadTitle(conversation: thread),
      body: Column(
        children: <Widget>[
          Expanded(
            child: AppMessageTimeline(
              state: messages.toViewState(
                (List<Message> items) => <AppMessageData>[
                  for (final Message item in items) item.toMessageData(),
                ],
                failure: strings.threadUnreadable,
                onRetry: () => ref.invalidate(
                  threadMessagesProvider(widget.conversationId),
                ),
              ),
              emptyTitle: strings.noMessages,
              emptyDescription: strings.sendFirstMessage,
              controller: _scroll,
              onRetry: (AppMessageData data) => _act(data, _retry),
              onDiscard: (AppMessageData data) => _act(data, _discard),
            ),
          ),
          MessageComposer(
            enabled: thread?.acceptsNewMessages ?? false,
            disabledReason: thread == null
                ? 'Loading conversation…'
                : 'This conversation is archived and cannot receive new '
                      'messages.',
            isSending: composer.isSending,
            onSend: (body) => ref
                .read(
                  conversationThreadControllerProvider(widget.conversationId)
                      .notifier,
                )
                .send(body),
          ),
        ],
      ),
    );
  }

  /// Runs [action] on the domain message a bubble was drawn from.
  void _act(AppMessageData data, void Function(Message message) action) {
    final Message? message = ref
        .read(threadMessagesProvider(widget.conversationId))
        .value
        ?.where((Message candidate) => candidate.id == data.id)
        .firstOrNull;
    if (message != null) {
      action(message);
    }
  }

  void _retry(Message message) {
    ref
        .read(
          conversationThreadControllerProvider(widget.conversationId).notifier,
        )
        .retry(message);
  }

  void _discard(Message message) {
    ref
        .read(
          conversationThreadControllerProvider(widget.conversationId).notifier,
        )
        .discard(message);
  }
}

class _ThreadTitle extends StatelessWidget {
  const _ThreadTitle({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        AppAvatar(
          name: conversation.displayName,
          imageUrl: conversation.customerAvatarUrl,
          size: 32,
        ),
        Expanded(
          child: Text(
            conversation.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium,
          ),
        ),
      ],
    );
  }
}
