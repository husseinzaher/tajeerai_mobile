import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A label that appears on long-press.
///
/// Honest about what it is on a phone: there is no hover, so this only ever
/// shows on a long-press, and a control whose meaning *depends* on it is a
/// control most people will never understand. The real accessibility answer is
/// the semantic label, which every component here already takes — this is for
/// the extra sentence, not for the only one.
class AppTooltip extends StatelessWidget {
  const AppTooltip({required this.message, required this.child, super.key});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final TajeerElevation surface = context.elevation.popover;

    return Tooltip(
      message: message,
      textStyle: context.type.labelSm.copyWith(color: colors.textPrimary),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.sm,
        vertical: TajeerSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surface.tone,
        borderRadius: TajeerRadii.mdAll,
        border: Border.fromBorderSide(BorderSide(color: surface.hairline)),
        boxShadow: surface.shadow,
      ),
      waitDuration: context.motion.slow,
      child: child,
    );
  }
}
