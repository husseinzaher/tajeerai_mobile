import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A rule with a word in the middle.
///
/// Named for its shape, not for the first place it was needed. It arrived as an
/// auth divider — "or continue with" — and calling it `AuthDivider` would have
/// guaranteed a second, identical widget the first time a conversation needed
/// to say "Yesterday" across a timeline. Which it will.
class AppLabelledSeparator extends StatelessWidget {
  const AppLabelledSeparator({
    required this.label,
    this.tone = AppSeparatorTone.muted,
    super.key,
  });

  final String label;
  final AppSeparatorTone tone;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final (Color ink, Color line) = switch (tone) {
      AppSeparatorTone.muted => (colors.textMuted, colors.border),
      AppSeparatorTone.primary => (colors.focus, colors.primaryBorder),
    };

    return Row(
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        Expanded(child: Divider(color: line, height: 1, thickness: 1)),
        Text(label, style: context.type.labelSm.copyWith(color: ink)),
        Expanded(child: Divider(color: line, height: 1, thickness: 1)),
      ],
    );
  }
}

/// How loudly the rule speaks.
///
/// [primary] is for the one that means something — the unread line in a
/// conversation, which a reader is meant to find rather than skim past.
enum AppSeparatorTone { muted, primary }
