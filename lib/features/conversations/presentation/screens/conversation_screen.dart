import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../design_system/design_system.dart';
import '../../application/ports/attachment_picker.dart';
import '../../application/ports/voice_recorder.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/conversation_note.dart';
import '../../domain/entities/message.dart';
import '../controllers/conversation_attachment_opener.dart';
import '../controllers/conversation_audio_controller.dart';
import '../controllers/conversation_record_controller.dart';
import '../controllers/conversation_thread_controller.dart';
import '../controllers/conversation_video_controller.dart';
import '../widgets/async_view_state.dart';
import '../widgets/attachment_view_data.dart';
import '../widgets/conversation_view_data.dart';
import '../widgets/customer_panel_sheet.dart';
import '../widgets/message_view_data.dart';
import '../../domain/value_objects/session_window.dart';

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
  /// Whether the composer is writing a note the customer never sees.
  bool _internalNote = false;

  final ScrollController _scroll = ScrollController();
  final AppComposerController _composer = AppComposerController();
  late final VoiceRecorder _voiceRecorder;
  late final ConversationAudioController _audio;
  late final ConversationVideoController _video;

  /// Now, for the window countdown. Held in state because the label changes
  /// while nothing else on the screen does.
  DateTime _now = DateTime.now();
  Timer? _windowTicker;

  /// Matches the WhatsApp channel capability set until channel metadata
  /// arrives with the conversation.
  static const AppChannelCapabilities _capabilities = AppChannelCapabilities(
    text: true,
    images: true,
    video: true,
    audio: true,
    documents: true,
  );

  /// How often the countdown re-reads the clock.
  ///
  /// Half a minute, because the label has minute granularity: slower and it
  /// sits visibly behind, faster and it rebuilds the thread for nothing.
  static const Duration _windowTick = Duration(seconds: 30);

  /// How close to the top of the thread, in logical pixels, the reader has to
  /// be before the page above is asked for. Well under a screen, so history
  /// arrives before they get there rather than when they are already looking
  /// at the edge.
  static const double _historyThreshold = 240;

  bool _recording = false;
  Duration _recordingElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Made rather than read: the recorder lives exactly as long as this
    // screen, and the screen disposes it. The factory is the port's, so
    // nothing here names the plugin that records.
    _voiceRecorder = ref.read(voiceRecorderFactoryProvider)()
      ..onElapsed = (Duration elapsed) {
        if (mounted) {
          setState(() => _recordingElapsed = elapsed);
        }
      };
    _audio = ConversationAudioController();
    _video = ConversationVideoController(
      cache: ref.read(messageMediaCoordinatorProvider),
      messages: ref.read(messageRepositoryProvider),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(
            conversationThreadControllerProvider(widget.conversationId)
                .notifier,
          )
          .loadInitial();
    });
  }

  /// Ticks only while there is something to count down.
  ///
  /// A thread whose window has closed, or one on a channel that has none, has
  /// a label that cannot change - and a timer behind it would be an interval
  /// running on every open conversation for nothing.
  void _syncWindowTicker(bool counting) {
    if (counting == (_windowTicker != null)) return;

    _windowTicker?.cancel();
    _windowTicker = counting
        ? Timer.periodic(_windowTick, (_) {
            if (mounted) setState(() => _now = DateTime.now());
          })
        : null;
  }

  @override
  void dispose() {
    _windowTicker?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _composer.dispose();
    unawaited(_voiceRecorder.dispose());
    unawaited(_audio.dispose());
    unawaited(_video.dispose());
    super.dispose();
  }

  ConversationThreadController get _thread => ref.read(
    conversationThreadControllerProvider(widget.conversationId).notifier,
  );

  /// Writes the composer's text onto the record instead of sending it.
  ///
  /// Answers like a send: true clears the field. A refused note keeps the
  /// text, and the controller's outcome says why in a toast.
  Future<bool> _addInternalNote(AppComposerDraft draft) async {
    final String body = (draft.text ?? '').trim();
    if (body.isEmpty) return false;

    final ConversationRecordController record = ref.read(
      conversationRecordControllerProvider(widget.conversationId).notifier,
    );
    await record.addNote(body);

    return ref
            .read(conversationRecordControllerProvider(widget.conversationId))
            .outcome ==
        RecordOutcome.noteSaved;
  }

  /// One entry of the record as the timeline draws it, with the sentence a
  /// log line reads as resolved here, in the reader's language. Null for a
  /// kind this build has no sentence for and no body to fall back on.
  AppRecordEntryData? _recordEntry(ConversationNote entry, AppStrings strings) {
    final String author = entry.authorName ?? strings.logSystem;
    final String? text = switch (entry.type) {
      'note' => entry.body,
      'summary' => entry.body,
      'closed' => entry.reason == null
          ? strings.logClosed.replaceAll('{name}', author)
          : strings.logClosedWithReason
                .replaceAll('{name}', author)
                .replaceAll('{reason}', strings.closeReasonName(entry.reason!)),
      'reopened' => strings.logReopened.replaceAll('{name}', author),
      _ => entry.body?.trim(),
    };
    if (text == null || text.isEmpty) return null;

    return AppRecordEntryData(
      id: entry.id,
      kind: switch (entry.type) {
        'note' => AppRecordKind.note,
        'summary' => AppRecordKind.summary,
        _ => AppRecordKind.log,
      },
      at: entry.createdAt,
      text: text,
      authorName: entry.authorName,
    );
  }

  /// The customer panel, over the thread.
  ///
  /// The panel's actions leave through the router rather than through the
  /// customers feature: a contact's own screen and the note form are routes,
  /// and a route is the one door every feature may use.
  Future<void> _openCustomerPanel(Conversation thread) {
    final String? customerId = thread.customerId;

    return AppBottomSheet.show<void>(
      context: context,
      sheet: CustomerPanelSheet(
        conversation: thread,
        onOpenCustomer: () {
          Navigator.of(context).pop();
          unawaited(
            context.push(
              customerId == null
                  ? AppRoutes.customerNewPath()
                  : AppRoutes.customerDetailPath(customerId),
            ),
          );
        },
        onAddReminder: customerId == null
            ? null
            : () {
                Navigator.of(context).pop();
                unawaited(
                  context.push(AppRoutes.customerNoteNewPath(customerId)),
                );
              },
      ),
    );
  }

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
    // Transient, and the one thing on this screen that is not read from the
    // database: a bubble that is true for a few seconds and then is not.
    final bool typing = ref.watch(threadTypingProvider(widget.conversationId));

    /*
      WhatsApp's 24-hour window, as the server reported it. The rule is the
      server's and the refusal is the server's; this decides only whether the
      member is told before they type or after they have tapped send.
    */
    final SessionWindow window =
        thread?.sessionWindow ?? SessionWindow.unreported;
    final bool windowClosed = window.isClosed(_now);
    final Duration? windowLeft = window.remaining(_now);

    _syncWindowTicker(windowLeft != null);

    // A downloaded attachment reaches the bubble through the database -- the
    // coordinator writes the path back and the query re-emits. The rebuild
    // here is for what it writes beside the database: a video poster on disk,
    // which the bubble finds by path. It is a rebuild, not a remount: the
    // timeline keeps its scroll position and its playing video across it.
    ref.listen(threadMessagesProvider(widget.conversationId), (
      AsyncValue<List<Message>>? previous,
      AsyncValue<List<Message>> next,
    ) {
      next.whenData((List<Message> items) {
        unawaited(() async {
          await ref.read(messageMediaCoordinatorProvider).cacheAll(items);
          if (mounted) setState(() {});
        }());
      });
    });

    // The thread's record, and the refresh that keeps it honest. Read from
    // the database like the messages; refreshed once per open thread.
    ref.watch(threadRecordRefreshProvider(widget.conversationId));
    final List<ConversationNote> record =
        ref.watch(threadRecordProvider(widget.conversationId)).value ??
        const <ConversationNote>[];
    final RecordActionState recordActions = ref.watch(
      conversationRecordControllerProvider(widget.conversationId),
    );

    ref.listen(conversationRecordControllerProvider(widget.conversationId), (
      RecordActionState? previous,
      RecordActionState next,
    ) {
      final RecordOutcome? outcome = next.outcome;
      if (outcome == null || outcome == previous?.outcome) return;

      AppSnackbar.show(
        context,
        message: switch (outcome) {
          RecordOutcome.noteSaved => strings.noteSaved,
          RecordOutcome.noteFailed => strings.noteSaveFailed,
          RecordOutcome.summaryDone => strings.summaryDone,
          RecordOutcome.summaryFailed => strings.summaryFailed,
        },
        tone: switch (outcome) {
          RecordOutcome.noteFailed ||
          RecordOutcome.summaryFailed => AppSnackbarTone.warning,
          _ => AppSnackbarTone.success,
        },
      );
      ref
          .read(conversationRecordControllerProvider(widget.conversationId).notifier)
          .clearOutcome();
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
      /*
        One strip, and the closed window outranks the failed count: on WhatsApp
        a closed window is usually *why* those messages failed, and it is the
        only one of the two that says what to do about it. The count is still
        on the rail's badge and on each failed bubble.
      */
      banner: _banner(
        strings: strings,
        thread: thread,
        window: window,
        windowClosed: windowClosed,
        windowLeft: windowLeft,
      ),
      toolbar: thread == null
          ? AppToolbar(showBack: true, onBack: () => context.pop())
          : AppToolbar.conversation(
              title: thread.toSummary(strings).title,
              avatarUrl: thread.customerAvatarUrl,
              onBack: () => context.pop(),
              // The person behind the thread, a tap away: the same panel the
              // web's inbox docks beside a conversation, as a sheet here.
              onTitleTap: () => _openCustomerPanel(thread),
            ),
      timeline: AppMessageTimeline(
        typing: typing,
        records: <AppRecordEntryData>[
          for (final ConversationNote entry in record)
            if (_recordEntry(entry, strings) case final AppRecordEntryData data)
              data,
        ],
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
        videoController: _video,
        onRetry: (AppMessageData data) => _act(data, _thread.retry),
        onDiscard: (AppMessageData data) => _act(data, _thread.discard),
        onLongPress: (AppMessageData data) => AppMessageActions.show(
          context,
          message: data,
          onRetry: () => _act(data, _thread.retry),
          onDiscard: () => _act(data, _thread.discard),
        ),
        onOpenAttachment: _openAttachment,
      ),
      composer: AppComposer(
        controller: _composer,
        capabilities: _capabilities,
        enabled: (thread?.acceptsNewMessages ?? false) && !windowClosed,
        disabledReason: switch (thread) {
          null => context.strings.loading,
          // Archived first: a read-only thread is read-only whatever the
          // window says, and "the customer must write in" would be a remedy
          // that does not work.
          final Conversation value when !value.acceptsNewMessages =>
            strings.archivedReadOnly,
          _ => strings.sessionExpiredHint,
        },
        sending: composer.isSending || recordActions.isSavingNote,
        hintText: strings.writeMessage,
        // An internal note goes to the thread's record, never to the
        // customer; everything else goes the way it always did.
        onSend: _internalNote ? _addInternalNote : _thread.sendDraft,
        internalNote: _internalNote,
        onInternalNoteChanged: (bool value) =>
            setState(() => _internalNote = value),
        onSummarize: () => unawaited(
          ref
              .read(
                conversationRecordControllerProvider(
                  widget.conversationId,
                ).notifier,
              )
              .summarize(),
        ),
        summarizing: recordActions.isSummarizing,
        // Reported when the field stops being empty and again when it empties,
        // never per keystroke -- the controller turns that into the customer's
        // bubble and keeps it alive while the reply is written.
        onTypingChanged: _thread.notifyTyping,
        onAttach: _attach,
        recording: _recording,
        recordingElapsed: _recordingElapsed,
        onRecordStart: _startRecording,
        onRecordStop: _stopRecording,
        onRecordCancel: _cancelRecording,
      ),
    );
  }

  /// The one strip above the timeline, or nothing.
  ///
  /// Priority is deliberate. A closed window is usually the reason messages
  /// failed and is the only one of the two that says what to do next; the
  /// failed count survives on the rail's badge and on every failed bubble. An
  /// open window is a quiet neutral line, the same one the web Inbox draws,
  /// because "six hours left" is worth knowing before a reply is written.
  Widget? _banner({
    required AppStrings strings,
    required Conversation? thread,
    required SessionWindow window,
    required bool windowClosed,
    required Duration? windowLeft,
  }) {
    if (windowClosed) {
      /*
        The condition only. The remedy - "the customer must write in first" -
        is the composer's `disabledReason`, where it sits against the control
        it explains. Saying the whole sentence twice, a finger apart, reads as
        two problems rather than one.
      */
      return AppStatusBanner(
        message: strings.sessionExpired,
        icon: LucideIcons.triangleAlert,
      );
    }

    if (thread != null && thread.hasFailedMessages) {
      // Says how many did not go out, in the same words the rail's badge
      // uses. Two phrasings for one problem read as two problems.
      return AppStatusBanner(
        message: AppMessages.interpolate(
          context.strings.failedCount,
          <String, Object?>{'count': thread.failedMessageCount},
        ),
        icon: LucideIcons.triangleAlert,
      );
    }

    // A channel with no window has nothing to say, and a strip announcing an
    // always-open session would be noise on every other transport.
    if (!window.isReported || windowLeft == null) {
      return null;
    }

    final int hours = windowLeft.inHours;
    final int minutes = windowLeft.inMinutes.remainder(60);

    return AppStatusBanner(
      tone: AppStatusTone.neutral,
      icon: LucideIcons.clock,
      message:
          '${strings.sessionActive} - '
          '${strings.sessionExpiresIn(hours > 0 ? strings.sessionRemainingHours(hours, minutes) : strings.sessionRemainingMinutes(minutes))}',
    );
  }

  /// The list is reversed, so its far end is the oldest message. Reaching it
  /// asks the controller for the page above; the controller decides whether
  /// there is one to ask for.
  void _onScroll() {
    if (!_scroll.hasClients) return;

    final ScrollPosition position = _scroll.position;

    if (position.maxScrollExtent - position.pixels <= _historyThreshold) {
      unawaited(_thread.loadOlder());
    }
  }

  Future<void> _attach() async {
    try {
      final PickedAttachment? picked = await ref
          .read(attachmentPickerProvider)
          .pick();

      if (picked != null && mounted) {
        _composer.addAttachment(picked.toAttachmentData());
      }
    } on FileSystemException {
      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: ref.read(appStringsProvider).sendNotSaved,
        tone: AppSnackbarTone.warning,
      );
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

  Future<void> _openAttachment(AppMessageData data) async {
    if (data.kind == AppMessageKind.video) return;

    final Message? message = ref
        .read(threadMessagesProvider(widget.conversationId))
        .value
        ?.where((Message candidate) => candidate.id == data.id)
        .firstOrNull;

    if (message == null || !mounted) return;

    final result = await ConversationAttachmentOpener.open(
      message: message,
      cache: ref.read(messageMediaCoordinatorProvider),
      messages: ref.read(messageRepositoryProvider),
    );

    if (!mounted || result.type == ResultType.done) return;

    AppSnackbar.show(
      context,
      message: ref.read(appStringsProvider).sendFailed,
      tone: AppSnackbarTone.warning,
    );
  }

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
