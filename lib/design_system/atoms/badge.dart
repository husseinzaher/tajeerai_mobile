import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

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
        colors.surfaceMuted,
        colors.textPrimary,
        Colors.transparent,
      ),
      AppBadgeVariant.destructive => (
        colors.dangerDefault,
        colors.textInverse,
        Colors.transparent,
      ),
      AppBadgeVariant.outline => (
        Colors.transparent,
        colors.textPrimary,
        colors.borderSubtle,
      ),
      AppBadgeVariant.success => (
        colors.successDefault,
        colors.textInverse,
        Colors.transparent,
      ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.sm, // `px-2.5`
        vertical: TajeerSpacing.xs2, // `py-0.5`
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: TajeerRadii.mdAll,
        border: Border.fromBorderSide(BorderSide(color: border)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: TajeerSpacing.xs2,
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
            style: context.type.labelSm.copyWith(
              fontFamily: TajeerTypography.sansFamily,
              fontFamilyFallback: TajeerTypography.sansFallback,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
