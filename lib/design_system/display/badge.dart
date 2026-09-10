import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// What a badge is saying.
///
/// `muted` is the quiet one: a count nobody has to act on, a tag. It is not
/// `outline` — that has an edge and no fill, and reads as a control.
enum AppBadgeVariant {
  primary,
  secondary,
  destructive,
  outline,
  success,
  warning,
  info,
  muted,
}

/// How much room it takes.
///
/// `small` is for a badge riding on something else — a count on an icon, a dot
/// on a tab — where the thing underneath is the subject.
enum AppBadgeSize { small, medium }

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
    this.size = AppBadgeSize.medium,
    this.leading,
    super.key,
  });

  /// An unread count.
  ///
  /// Above [ceiling] it becomes "99+": a four-digit badge stops being a number
  /// anybody reads and starts being a shape that breaks the row it sits in.
  /// A factory rather than a generative constructor: the label is computed
  /// from the count, so it can never be const, and a non-const generative
  /// constructor on an immutable class is a lint with a real point behind it.
  factory AppBadge.count(int value, {int ceiling = 99, Key? key}) => AppBadge(
    label: value > ceiling ? '$ceiling+' : '$value',
    size: AppBadgeSize.small,
    key: key,
  );

  /// A marker with no number in it: something changed, and that is all.
  const AppBadge.dot({super.key})
    : label = '',
      variant = AppBadgeVariant.primary,
      size = AppBadgeSize.small,
      leading = null;

  final String label;
  final AppBadgeVariant variant;
  final AppBadgeSize size;
  final Widget? leading;

  bool get _isDot => label.isEmpty && leading == null;

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
      AppBadgeVariant.warning => (
        colors.warningDefault,
        colors.textInverse,
        Colors.transparent,
      ),
      AppBadgeVariant.info => (
        colors.infoDefault,
        colors.textInverse,
        Colors.transparent,
      ),
      AppBadgeVariant.muted => (
        colors.surfaceMuted,
        colors.textMuted,
        Colors.transparent,
      ),
    };

    if (_isDot) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      );
    }

    final bool small = size == AppBadgeSize.small;

    return Container(
      constraints: BoxConstraints(minWidth: small ? 20 : 0),
      alignment: small ? Alignment.center : null,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: small ? TajeerSpacing.xs2 : TajeerSpacing.sm,
        vertical: TajeerSpacing.xs2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: small ? TajeerRadii.fullAll : TajeerRadii.mdAll,
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
