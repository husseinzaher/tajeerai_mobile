import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../../../app/theme/theme.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../controllers/conversation_thread_controller.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';

/// One conversation.
///
/// Reads its messages from the local database. A message arriving over the
/// socket appears here because the realtime handler wrote a row and the
/// reactive query re-emitted -- this screen has no socket subscription and no
/// message list of its own to keep in step.
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
            child: messages.when(
              loading: () => const _ThreadSkeleton(),
              error: (error, _) => AppErrorState(
                message: 'This conversation could not be read.',
                bordered: false,
                onRetry: () => ref.invalidate(
                  threadMessagesProvider(widget.conversationId),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const AppEmptyState(
                    title: 'No messages yet',
                    description: 'Send the first message in this conversation.',
                    icon: LucideIcons.messageSquare,
                    bordered: false,
                  );
                }

                return ListView.separated(
                  controller: _scroll,
                  // Newest at the bottom: the list is reversed so it opens
                  // pinned to the latest message, and older history loads
                  // as the reader scrolls up.
                  reverse: true,
                  padding: const EdgeInsets.all(TajeerSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: TajeerSpacing.xs),
                  itemBuilder: (context, index) {
                    final message = items[items.length - 1 - index];

                    return MessageBubble(
                      message: message,
                      onRetry: message.state.canRetry
                          ? () => _retry(message)
                          : null,
                      onDiscard: message.state.canRetry
                          ? () => _discard(message)
                          : null,
                    );
                  },
                );
              },
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

class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(TajeerSpacing.md),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isOutbound = index.isEven;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
          child: Align(
            alignment: isOutbound
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: AppSkeleton(width: isOutbound ? 180 : 220, height: 40),
          ),
        );
      },
    );
  }
}
