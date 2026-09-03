import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/radii.dart';
import '../../app/theme/spacing.dart';
import '../../app/theme/typography.dart';

/// The four badge variants from `badge.tsx`.
enum AppBadgeVariant { primary, secondary, destructive, outline, success }

/// A small status pill.
///
/// `rounded-md border px-2.5 py-0.5 text-xs font-semibold`, never wrapping.
/// `success` is not in the web's `cva` set but the token is -- the unread and
/// delivery states need it, and adding a variant to the existing family is the
/// system's own rule for this.
class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.variant = AppBadgeVariant.primary,
    this.leading,
    super.key,
  });

  final String label;
  final AppBadgeVariant variant;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (background, foreground, border) = switch (variant) {
      AppBadgeVariant.primary => (
        colors.primary,
        colors.primaryForeground,
        Colors.transparent,
      ),
      AppBadgeVariant.secondary => (
        colors.secondary,
        colors.secondaryForeground,
        Colors.transparent,
      ),
      AppBadgeVariant.destructive => (
        colors.destructive,
        colors.destructiveForeground,
        Colors.transparent,
      ),
      AppBadgeVariant.outline => (
        Colors.transparent,
        colors.foreground,
        colors.badgeOutline,
      ),
      AppBadgeVariant.success => (
        colors.success,
        colors.successForeground,
        Colors.transparent,
      ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.x2_5, // `px-2.5`
        vertical: TajeerSpacing.x0_5, // `py-0.5`
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: TajeerRadii.mdAll,
        border: Border.fromBorderSide(BorderSide(color: border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: TajeerSpacing.x1,
        children: <Widget>[
          if (leading != null)
            IconTheme.merge(
              data: IconThemeData(color: foreground, size: 12),
              child: leading!,
            ),
          Text(
            label,
            maxLines: 1,
            softWrap: false, // `whitespace-nowrap`
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TajeerTypography.sansFamily,
              fontFamilyFallback: TajeerTypography.sansFallback,
              fontSize: TajeerTypography.xs,
              height: 16 / TajeerTypography.xs,
              fontWeight: TajeerTypography.semibold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
