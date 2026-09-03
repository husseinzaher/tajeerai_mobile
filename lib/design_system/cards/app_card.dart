import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/radii.dart';
import '../../app/theme/shadows.dart';
import '../../app/theme/spacing.dart';
import '../atoms/pressable.dart';

/// The system's surface container.
///
/// `card.tsx` is `rounded-xl border bg-card text-card-foreground shadow`, with
/// `p-6` sections. Given [onTap] it becomes pressable and picks up the same
/// elevate overlay as every other interactive surface, which is how the web's
/// clickable cards behave.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(TajeerSpacing.x6),
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
        color: selected ? colors.primaryMuted : colors.card,
        borderRadius: TajeerRadii.xlAll,
        border: Border.fromBorderSide(
          BorderSide(color: selected ? colors.primary : colors.border),
        ),
        boxShadow: TajeerShadows.base,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.cardForeground),
        child: child,
      ),
    );

    if (onTap == null) return surface;

    return Pressable(
      onTap: onTap,
      borderRadius: TajeerRadii.xlAll,
      semanticLabel: semanticLabel,
      child: surface,
    );
  }
}

/// The `CardHeader` / `CardTitle` / `CardDescription` stack.
///
/// Kept as one widget rather than three: the web splits them because JSX needs
/// somewhere to hang `space-y-1.5`, and three Flutter widgets whose only job
/// is vertical spacing would be ceremony without a purpose.
class AppCardHeader extends StatelessWidget {
  const AppCardHeader({
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: TajeerSpacing.x1_5, // `space-y-1.5`
            children: <Widget>[
              Text(
                title,
                // `font-semibold leading-none tracking-tight`.
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: colors.cardForeground,
                ),
              ),
              if (description != null)
                Text(
                  description!,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
