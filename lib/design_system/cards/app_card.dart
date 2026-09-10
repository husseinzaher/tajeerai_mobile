import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';

/// The system's surface container.
///
/// `card.tsx` is `rounded-xl border bg-card text-card-foreground shadow`, with
/// `p-6` sections. Given [onTap] it becomes pressable and picks up the same
/// elevate overlay as every other interactive surface, which is how the web's
/// clickable cards behave.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(TajeerSpacing.lg),
    this.onTap,
    this.selected = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Selected rows take the tinted primary wash the rail uses, not a border
  /// colour change -- `primaryMuted` exists for exactly this.
  final bool selected;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? colors.primarySoft : colors.surface,
        borderRadius: TajeerRadii.xlAll,
        border: Border.fromBorderSide(
          BorderSide(color: selected ? colors.primary : colors.border),
        ),
        boxShadow: context.elevation.card.shadow,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.textPrimary),
        child: child,
      ),
    );

    if (onTap == null) return surface;

    return AppPressable(
      onTap: onTap,
      borderRadius: TajeerRadii.xlAll,
      semanticLabel: semanticLabel,
      child: surface,
    );
  }
}
