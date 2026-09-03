import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../design_system/loaders/spinner.dart';
import '../../domain/entities/message.dart';

/// One message in a thread.
///
/// The inbound surface uses `muted` and the outbound one `primary`, which is
/// how the web Inbox distinguishes them. Both corners are `radius-lg` except
/// the one nearest the speaker, which is tightened -- the tail, without
/// drawing one.
///
/// Alignment is *logical*: `start`/`end` rather than left/right, so the thread
/// mirrors correctly in Arabic without a second layout.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.onRetry,
    this.onDiscard,
    super.key,
  });

  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOutbound = message.isOutbound;

    final background = isOutbound ? colors.primary : colors.muted;
    final foreground = isOutbound
        ? colors.primaryForeground
        : colors.foreground;

    return Align(
      alignment: isOutbound
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        // A bubble that spans the full width is hard to read and hides which
        // side it came from.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: isOutbound
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: TajeerSpacing.x1,
          children: <Widget>[
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.x3,
                vertical: TajeerSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(TajeerRadii.lg),
                  topEnd: const Radius.circular(TajeerRadii.lg),
                  bottomStart: Radius.circular(
                    isOutbound ? TajeerRadii.lg : TajeerRadii.sm,
                  ),
                  bottomEnd: Radius.circular(
                    isOutbound ? TajeerRadii.sm : TajeerRadii.lg,
                  ),
                ),
                // A failed message is outlined so it reads as needing
                // attention even before its status line is read.
                border: message.state == MessageState.failed
                    ? Border.fromBorderSide(
                        BorderSide(color: colors.destructive),
                      )
                    : null,
              ),
              child: Text(
                message.body ?? _placeholderFor(message),
                style: context.text.bodyLarge?.copyWith(color: foreground),
              ),
            ),
            _StatusLine(message: message),
            if (message.state.canRetry &&
                (onRetry != null || onDiscard != null))
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: TajeerSpacing.x3,
                children: <Widget>[
                  if (onRetry != null)
                    _InlineAction(label: 'Retry', onTap: onRetry!),
                  if (onDiscard != null)
                    _InlineAction(
                      label: 'Discard',
                      onTap: onDiscard!,
                      destructive: true,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// What to show for a message this build cannot render.
  ///
  /// The provider's type vocabulary grows server-side; an unknown type has to
  /// degrade to a line of text rather than an empty bubble or a crash.
  static String _placeholderFor(Message message) {
    if (message.mediaUrl != null) return 'Attachment';

    return 'Unsupported message';
  }
}

/// Time plus delivery state, under the bubble.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (icon, label, color) = switch (message.state) {
      MessageState.pending => (
        LucideIcons.clock,
        'Waiting to send',
        colors.mutedForeground,
      ),
      MessageState.sending => (null, 'Sending', colors.mutedForeground),
      MessageState.failed => (
        LucideIcons.circleAlert,
        'Not sent',
        colors.destructive,
      ),
      MessageState.sent => (LucideIcons.check, null, colors.mutedForeground),
      MessageState.delivered => (
        LucideIcons.checkCheck,
        null,
        colors.mutedForeground,
      ),
      MessageState.read => (LucideIcons.checkCheck, null, colors.accent),
      MessageState.discarded => (
        LucideIcons.ban,
        'Removed',
        colors.mutedForeground,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.x1,
      children: <Widget>[
        Text(
          DateFormat.jm().format(message.createdAt.toLocal()),
          style: context.text.bodySmall?.copyWith(
            color: colors.mutedForeground,
          ),
        ),
        if (message.isOutbound) ...<Widget>[
          if (message.state == MessageState.sending)
            Spinner(size: 10, color: color)
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          if (label != null)
            Text(label, style: context.text.bodySmall?.copyWith(color: color)),
        ],
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        child: Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: destructive ? colors.destructive : colors.primary,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationColor: destructive ? colors.destructive : colors.primary,
          ),
        ),
      ),
    );
  }
}
