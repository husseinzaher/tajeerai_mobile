import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../controllers/conversation_thread_controller.dart';
import '../widgets/async_view_state.dart';
import '../widgets/conversation_view_data.dart';
import '../widgets/message_view_data.dart';

/// One conversation.
///
/// Reads its messages from the local database. A message arriving over the
/// socket appears here because the realtime handler wrote a row and the
/// reactive query re-emitted -- this screen has no socket subscription and no
/// message list of its own to keep in step.
///
/// Composition, and nothing else: the header, the thread, the composer and the
/// long-press menu are the design system's. What this screen owns is which
/// actions exist. Today a member can send text, copy, retry and discard; the
/// composer's paperclip, microphone and reply strip appear the day the send
/// path can carry a file, a voice note or a reply.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scroll = ScrollController();
  final AppComposerController _composer = AppComposerController();

  /// What the send path carries today: words.
  static const AppChannelCapabilities _capabilities =
      AppChannelCapabilities.textOnly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(
            conversationThreadControllerProvider(widget.conversationId)
                .notifier,
          )
          .loadInitial();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  ConversationThreadController get _thread => ref.read(
    conversationThreadControllerProvider(widget.conversationId).notifier,
  );

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Conversation? thread = ref
        .watch(threadConversationProvider(widget.conversationId))
        .value;
    final messages = ref.watch(threadMessagesProvider(widget.conversationId));
    final ComposerState composer = ref.watch(
      conversationThreadControllerProvider(widget.conversationId),
    );

    // Composer failures are transient notices, not a screen state -- the thread
    // behind them is still perfectly readable.
    ref.listen(conversationThreadControllerProvider(widget.conversationId), (
      ComposerState? previous,
      ComposerState next,
    ) {
      final ComposerError? error = next.error;
      if (error == null || error == previous?.error) return;

      AppSnackbar.show(
        context,
        message: _describe(error, strings),
        tone: AppSnackbarTone.warning,
      );
      _thread.clearError();
    });

    return AppConversationShell(
      toolbar: thread == null
          ? AppToolbar(showBack: true, onBack: () => context.pop())
          : AppToolbar.conversation(
              title: thread.toSummary(strings).title,
              avatarUrl: thread.customerAvatarUrl,
              onBack: () => context.pop(),
            ),
      timeline: AppMessageTimeline(
        state: messages.toViewState(
          (List<Message> items) => <AppMessageData>[
            for (final Message item in items) item.toMessageData(),
          ],
          failure: strings.threadUnreadable,
          onRetry: () =>
              ref.invalidate(threadMessagesProvider(widget.conversationId)),
        ),
        emptyTitle: strings.noMessages,
        emptyDescription: strings.sendFirstMessage,
        controller: _scroll,
        onRetry: (AppMessageData data) => _act(data, _thread.retry),
        onDiscard: (AppMessageData data) => _act(data, _thread.discard),
        onLongPress: (AppMessageData data) => AppMessageActions.show(
          context,
          message: data,
          onRetry: () => _act(data, _thread.retry),
          onDiscard: () => _act(data, _thread.discard),
        ),
      ),
      composer: AppComposer(
        controller: _composer,
        capabilities: _capabilities,
        enabled: thread?.acceptsNewMessages ?? false,
        disabledReason: thread == null
            ? context.strings.loading
            : strings.archivedReadOnly,
        sending: composer.isSending,
        hintText: strings.writeMessage,
        onSend: (AppComposerDraft draft) => _thread.send(draft.text),
      ),
    );
  }

  static String _describe(ComposerError error, AppStrings strings) =>
      switch (error) {
        ComposerError.refused => strings.sendRefused,
        ComposerError.offline => strings.sendOffline,
        ComposerError.notSaved => strings.sendNotSaved,
        ComposerError.unknown => strings.sendFailed,
      };

  /// Runs [action] on the domain message a bubble was drawn from.
  void _act(AppMessageData data, Future<void> Function(Message) action) {
    final Message? message = ref
        .read(threadMessagesProvider(widget.conversationId))
        .value
        ?.where((Message candidate) => candidate.id == data.id)
        .firstOrNull;
    if (message != null) {
      action(message);
    }
  }
}
