import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../controllers/conversation_thread_controller.dart';
import '../../application/coordinators/conversation_voice_recorder.dart';
import '../controllers/conversation_audio_controller.dart';
import '../controllers/conversation_media_picker.dart';
import '../widgets/async_view_state.dart';
import '../widgets/conversation_view_data.dart';
import '../widgets/message_view_data.dart';

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
  final AppComposerController _composer = AppComposerController();
  late final ConversationVoiceRecorder _voiceRecorder;
  late final ConversationAudioController _audio;

  /// Matches the WhatsApp channel capability set until channel metadata
  /// arrives with the conversation.
  static const AppChannelCapabilities _capabilities = AppChannelCapabilities(
    text: true,
    images: true,
    video: true,
    audio: true,
    documents: true,
  );

  bool _recording = false;
  Duration _recordingElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _voiceRecorder = ConversationVoiceRecorder()
      ..onElapsed = (Duration elapsed) {
        if (mounted) {
          setState(() => _recordingElapsed = elapsed);
        }
      };
    _audio = ConversationAudioController();

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
    unawaited(_voiceRecorder.dispose());
    unawaited(_audio.dispose());
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

    ref.listen(threadMessagesProvider(widget.conversationId), (
      AsyncValue<List<Message>>? previous,
      AsyncValue<List<Message>> next,
    ) {
      next.whenData((List<Message> items) {
        unawaited(ref.read(messageMediaCoordinatorProvider).cacheAll(items));
      });
    });

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
        audioController: _audio,
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
        onSend: _thread.sendDraft,
        onAttach: _attach,
        recording: _recording,
        recordingElapsed: _recordingElapsed,
        onRecordStart: _startRecording,
        onRecordStop: _stopRecording,
        onRecordCancel: _cancelRecording,
      ),
    );
  }

  Future<void> _attach() async {
    final AppAttachmentData? picked = await ConversationMediaPicker.pick();

    if (picked != null && mounted) {
      _composer.addAttachment(picked);
    }
  }

  Future<void> _startRecording() async {
    final bool started = await _voiceRecorder.start();

    if (!started || !mounted) return;

    setState(() {
      _recording = true;
      _recordingElapsed = Duration.zero;
    });
  }

  Future<void> _stopRecording() async {
    final String? path = await _voiceRecorder.stop();

    if (mounted) {
      setState(() {
        _recording = false;
        _recordingElapsed = Duration.zero;
      });
    }

    if (path != null) {
      await _thread.sendVoice(path);
    }
  }

  Future<void> _cancelRecording() async {
    await _voiceRecorder.cancel();

    if (mounted) {
      setState(() {
        _recording = false;
        _recordingElapsed = Duration.zero;
      });
    }
  }

  static String _describe(ComposerError error, AppStrings strings) =>
      switch (error) {
        ComposerError.refused => strings.sendRefused,
        ComposerError.offline => strings.sendOffline,
        ComposerError.notSaved => strings.sendNotSaved,
        ComposerError.unknown => strings.sendFailed,
      };

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
