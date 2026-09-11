import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../loaders/spinner.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import 'message_data.dart';

/// A message's delivery, as a glyph — and a word where the member has to wait
/// or act.
///
/// Sent, delivered and read speak through their ticks alone: a word under
/// every message that arrived is noise. Delivered and read differ only in the
/// tint, which is the convention every messaging app has taught; a screen
/// reader hears the difference in words.
class AppMessageStatusIcon extends StatelessWidget {
  const AppMessageStatusIcon({required this.status, this.size = 14, super.key});

  final AppMessageStatus status;
  final double size;

  /// What a screen reader hears. Null for a message with no delivery to report.
  static String? labelFor(AppMessageStatus status, AppMessages strings) =>
      switch (status) {
        AppMessageStatus.none => null,
        AppMessageStatus.queued => strings.queued,
        AppMessageStatus.sending => strings.sending,
        AppMessageStatus.notSent => strings.notSent,
        AppMessageStatus.sent => strings.sent,
        AppMessageStatus.delivered => strings.delivered,
        AppMessageStatus.read => strings.readReceipt,
        AppMessageStatus.removed => strings.removed,
      };

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final String? label = labelFor(status, context.strings);
    if (label == null) {
      return const SizedBox.shrink();
    }

    Icon glyph(IconData icon, Color color) =>
        Icon(icon, size: size, color: color);

    final (Widget mark, Color ink, bool worded) = switch (status) {
      AppMessageStatus.queued => (
        glyph(LucideIcons.clock, colors.textMuted),
        colors.textMuted,
        true,
      ),
      AppMessageStatus.sending => (
        AppSpinner(size: size - 2, color: colors.textMuted),
        colors.textMuted,
        true,
      ),
      AppMessageStatus.notSent => (
        glyph(LucideIcons.circleAlert, colors.dangerDefault),
        colors.dangerDefault,
        true,
      ),
      AppMessageStatus.sent => (
        glyph(LucideIcons.check, colors.textMuted),
        colors.textMuted,
        false,
      ),
      AppMessageStatus.delivered => (
        glyph(LucideIcons.checkCheck, colors.textMuted),
        colors.textMuted,
        false,
      ),
      AppMessageStatus.read => (
        glyph(LucideIcons.checkCheck, colors.infoDefault),
        colors.infoDefault,
        false,
      ),
      AppMessageStatus.removed => (
        glyph(LucideIcons.ban, colors.textMuted),
        colors.textMuted,
        true,
      ),
      AppMessageStatus.none => (
        const SizedBox.shrink(),
        colors.textMuted,
        false,
      ),
    };

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TajeerSpacing.xs2,
          children: <Widget>[
            mark,
            if (worded)
              Text(label, style: context.type.caption.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}
