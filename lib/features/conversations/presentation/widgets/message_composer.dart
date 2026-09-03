import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../design_system/buttons/app_button.dart';
import '../../../../design_system/inputs/app_text_field.dart';

/// The message input.
///
/// Disabled with an explanation rather than hidden when a thread will not
/// accept messages -- an archived conversation whose composer silently
/// vanishes looks broken, while one that says why does not.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.onSend,
    this.enabled = true,
    this.disabledReason,
    this.isSending = false,
    this.onTypingChanged,
    super.key,
  });

  /// Returns true when the message was accepted, which is the signal to clear
  /// the field. A refused send keeps the text so it is not lost.
  final Future<bool> Function(String body) onSend;

  final bool enabled;
  final String? disabledReason;
  final bool isSending;

  /// Fired as the user starts and stops typing.
  final ValueChanged<bool>? onTypingChanged;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _wasTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;

    // Only on the edge. A callback per keystroke would put a socket frame on
    // the wire for every character.
    if (isTyping != _wasTyping) {
      _wasTyping = isTyping;
      widget.onTypingChanged?.call(isTyping);
    }

    setState(() {});
  }

  Future<void> _send() async {
    final body = _controller.text;

    if (body.trim().isEmpty) return;

    final sent = await widget.onSend(body);

    if (!sent) return;

    _controller.clear();
    _wasTyping = false;
    widget.onTypingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!widget.enabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(TajeerSpacing.x4),
        decoration: BoxDecoration(
          color: colors.muted,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: Text(
          widget.disabledReason ?? 'This conversation is read-only.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: colors.mutedForeground,
          ),
        ),
      );
    }

    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(TajeerSpacing.x3),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: TajeerSpacing.x2,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                controller: _controller,
                hintText: 'Write a message',
                // Grows to five lines, then scrolls -- a long message must not
                // push the send button off the screen.
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
            Padding(
              // Keeps the button aligned with the field's first line as the
              // field grows.
              padding: const EdgeInsets.only(bottom: 2),
              child: AppButton.icon(
                icon: const Icon(LucideIcons.send),
                semanticLabel: 'Send message',
                variant: AppButtonVariant.primary,
                loading: widget.isSending,
                onPressed: hasText && !widget.isSending ? _send : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "someone is typing" line.
///
/// A separate widget so it can appear and disappear without rebuilding the
/// composer or the message list.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.x4,
        vertical: TajeerSpacing.x2,
      ),
      child: Row(
        spacing: TajeerSpacing.x2,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: TajeerRadii.fullAll,
            ),
          ),
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
