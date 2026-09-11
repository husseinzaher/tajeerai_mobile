import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../channels/channel_capabilities.dart';
import '../inputs/app_text_field.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import 'attachment_previews.dart';
import 'message_data.dart';
import 'quick_reply_bar.dart';
import 'reply_preview.dart';
import 'voice_record_button.dart';

/// What the composer hands the app when a member sends.
@immutable
class AppComposerDraft {
  const AppComposerDraft({
    required this.text,
    this.replyTo,
    this.attachments = const <AppAttachmentData>[],
  });

  final String text;
  final AppReplyData? replyTo;
  final List<AppAttachmentData> attachments;
}

/// What is being written: the words, the message they answer, and the files
/// going with them.
///
/// Owned by the screen, so a reply can be started from a bubble's long press
/// and a file added from a picker the design system knows nothing about,
/// without either one reaching into the composer.
class AppComposerController extends ChangeNotifier {
  AppComposerController({String text = ''})
    : text = TextEditingController(text: text) {
    this.text.addListener(notifyListeners);
  }

  final TextEditingController text;

  AppReplyData? _replyTo;
  List<AppAttachmentData> _attachments = const <AppAttachmentData>[];

  AppReplyData? get replyTo => _replyTo;
  List<AppAttachmentData> get attachments => _attachments;

  /// Words, or at least one file. Whitespace alone is not a message.
  bool get canSend => text.text.trim().isNotEmpty || _attachments.isNotEmpty;

  AppComposerDraft get draft => AppComposerDraft(
    text: text.text,
    replyTo: _replyTo,
    attachments: _attachments,
  );

  void startReply(AppReplyData reply) {
    _replyTo = reply;
    notifyListeners();
  }

  void cancelReply() {
    if (_replyTo == null) {
      return;
    }
    _replyTo = null;
    notifyListeners();
  }

  void addAttachment(AppAttachmentData attachment) {
    _attachments = <AppAttachmentData>[..._attachments, attachment];
    notifyListeners();
  }

  void removeAttachment(AppAttachmentData attachment) {
    final int index = _attachments.indexOf(attachment);
    if (index < 0) {
      return;
    }
    _attachments = <AppAttachmentData>[..._attachments]..removeAt(index);
    notifyListeners();
  }

  /// Empties the composer, once the app has accepted what was sent.
  void clear() {
    text.clear();
    _replyTo = null;
    _attachments = const <AppAttachmentData>[];
    notifyListeners();
  }

  @override
  void dispose() {
    text
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// Where a message is written.
///
/// **Capabilities decide the controls, never the channel.** The paperclip is
/// there when the channel can carry a file and the app can pick one; the
/// microphone when it can carry a voice note and the app can record one; the
/// reply strip when it takes replies. An SMS thread gets words and a send
/// button, and nothing anywhere asks whether it is SMS.
///
/// **A refused send keeps the text.** [onSend] answers whether the app took the
/// message, and only a yes empties the composer — an offline failure must not
/// cost a member what they typed.
///
/// A conversation that takes no messages shows why, instead of a composer that
/// silently is not there and looks broken.
class AppComposer extends StatefulWidget {
  const AppComposer({
    required this.controller,
    required this.onSend,
    this.capabilities = AppChannelCapabilities.textOnly,
    this.enabled = true,
    this.disabledReason,
    this.sending = false,
    this.hintText,
    this.onAttach,
    this.recording = false,
    this.recordingElapsed = Duration.zero,
    this.onRecordStart,
    this.onRecordStop,
    this.onRecordCancel,
    this.onTypingChanged,
    this.quickReplies = const <String>[],
    super.key,
  });

  final AppComposerController controller;
  final Future<bool> Function(AppComposerDraft draft) onSend;
  final AppChannelCapabilities capabilities;

  final bool enabled;

  /// Why a disabled composer is disabled. Defaults to "read-only".
  final String? disabledReason;

  /// The send is being written. The button waits, and the text stays.
  final bool sending;

  final String? hintText;

  /// Opens the app's picker. Without it there is no paperclip.
  final VoidCallback? onAttach;

  final bool recording;
  final Duration recordingElapsed;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
  final VoidCallback? onRecordCancel;

  /// Reported only when typing starts or stops. One callback per keystroke
  /// would put a socket frame on the wire for every character.
  final ValueChanged<bool>? onTypingChanged;

  final List<String> quickReplies;

  @override
  State<AppComposer> createState() => _AppComposerState();
}

class _AppComposerState extends State<AppComposer> {
  bool _wasTyping = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(AppComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final bool typing = widget.controller.text.text.trim().isNotEmpty;
    if (typing != _wasTyping) {
      _wasTyping = typing;
      widget.onTypingChanged?.call(typing);
    }
    setState(() {});
  }

  Future<void> _send() async {
    final AppComposerController controller = widget.controller;
    if (!controller.canSend || widget.sending) {
      return;
    }
    final bool accepted = await widget.onSend(controller.draft);
    if (accepted && mounted) {
      controller.clear();
    }
  }

  void _fill(String reply) {
    widget.controller.text.value = TextEditingValue(
      text: reply,
      selection: TextSelection.collapsed(offset: reply.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;

    if (!widget.enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(TajeerSpacing.md),
            child: Text(
              widget.disabledReason ?? strings.readOnly,
              textAlign: TextAlign.center,
              style: context.type.bodyMd.copyWith(color: colors.textMuted),
            ),
          ),
        ),
      );
    }

    final AppComposerController controller = widget.controller;
    final AppChannelCapabilities can = widget.capabilities;
    final bool attach = can.canAttach && widget.onAttach != null;
    final bool record = can.audio && widget.onRecordStart != null;
    final AppReplyData? reply = can.replies ? controller.replyTo : null;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.quickReplies.isNotEmpty && !widget.recording)
              AppQuickReplyBar(replies: widget.quickReplies, onSelected: _fill),
            if (reply != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TajeerSpacing.sm,
                  TajeerSpacing.sm,
                  TajeerSpacing.sm,
                  0,
                ),
                child: AppReplyPreview(
                  reply: reply,
                  onDismiss: controller.cancelReply,
                ),
              ),
            if (controller.attachments.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TajeerSpacing.sm,
                  TajeerSpacing.sm,
                  TajeerSpacing.sm,
                  0,
                ),
                child: Row(
                  spacing: TajeerSpacing.xs,
                  children: <Widget>[
                    for (final AppAttachmentData file in controller.attachments)
                      AppAttachmentPreview(
                        attachment: file,
                        onRemove: () => controller.removeAttachment(file),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(TajeerSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: TajeerSpacing.xs,
                children: <Widget>[
                  if (attach && !widget.recording)
                    AppButton.icon(
                      icon: const Icon(LucideIcons.paperclip),
                      semanticLabel: strings.attach,
                      onPressed: widget.onAttach,
                    ),
                  Expanded(
                    child: widget.recording
                        ? _RecordingStrip(elapsed: widget.recordingElapsed)
                        : AppTextField(
                            controller: controller.text,
                            hintText: widget.hintText,
                            // Grows to five lines, then scrolls: a long
                            // message must not push the send button away.
                            maxLines: 5,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                  ),
                  Padding(
                    // Keeps the button level with the field's last line as
                    // the field grows.
                    padding: const EdgeInsets.only(bottom: 2),
                    child: widget.recording || (record && !controller.canSend)
                        ? AppVoiceRecordButton(
                            recording: widget.recording,
                            onStart: widget.onRecordStart,
                            onStop: widget.onRecordStop,
                            onCancel: widget.onRecordCancel,
                          )
                        : AppButton.icon(
                            // The arrow points the way the line runs.
                            icon: Transform.flip(
                              flipX: rtl,
                              child: const Icon(LucideIcons.send),
                            ),
                            semanticLabel: strings.send,
                            variant: AppButtonVariant.primary,
                            loading: widget.sending,
                            onPressed: controller.canSend && !widget.sending
                                ? () => unawaited(_send())
                                : null,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the field was, while a voice note is recording.
class _RecordingStrip extends StatelessWidget {
  const _RecordingStrip({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final String clock = AppAudioPlayback.clock(elapsed);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${strings.recording} $clock',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            spacing: TajeerSpacing.sm,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.dangerDefault,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                clock,
                style: context.type.labelMd.copyWith(color: colors.textPrimary),
              ),
              Expanded(
                child: Text(
                  strings.slideToCancel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
