import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/radii.dart';
import '../../app/theme/spacing.dart';
import '../../app/theme/shadows.dart';
import '../../app/theme/typography.dart';
import '../atoms/pressable.dart';
import '../loaders/spinner.dart';

/// The six button variants, matching `button.tsx`'s `cva` set.
enum AppButtonVariant { primary, destructive, outline, secondary, ghost, link }

/// The four sizes: `default`, `sm`, `lg`, `icon`.
enum AppButtonSize { medium, small, large, icon }

/// The system's button.
///
/// A direct port of the design system's `Button`: same variants, same sizes,
/// same `rounded-md` corner, and the same interaction model -- no hover colour
/// per variant, just the shared elevate overlay from [Pressable]. The border
/// on the opaque variants is computed from the surface colour the way the web
/// theme computes `--primary-border`, rather than being a second token.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.leading,
    this.trailing,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
    super.key,
  });

  /// Icon-only. [semanticLabel] is required because there is no text to read.
  const AppButton.icon({
    required Widget icon,
    required String this.semanticLabel,
    this.onPressed,
    this.variant = AppButtonVariant.ghost,
    this.loading = false,
    super.key,
  }) : label = null,
       leading = icon,
       trailing = null,
       size = AppButtonSize.icon,
       expand = false;

  final String? label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final Widget? leading;
  final Widget? trailing;

  /// Swaps the leading slot for a spinner and blocks the tap. The label stays
  /// put so the button does not change width mid-press.
  final bool loading;

  final bool expand;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = _style(colors);
    final metrics = _metrics();

    final content = <Widget>[
      if (loading)
        Spinner(size: 16, color: style.foreground)
      else if (leading != null)
        IconTheme.merge(
          data: IconThemeData(color: style.foreground, size: 16),
          child: leading!,
        ),
      if (label != null)
        Flexible(
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontFamily: TajeerTypography.sansFamily,
              fontFamilyFallback: TajeerTypography.sansFallback,
              fontSize: metrics.fontSize,
              height: metrics.lineHeight / metrics.fontSize,
              fontWeight: TajeerTypography.medium,
              color: style.foreground,
              decoration: variant == AppButtonVariant.link
                  ? TextDecoration.underline
                  : null,
              decorationColor: style.foreground,
            ),
          ),
        ),
      if (trailing != null)
        IconTheme.merge(
          data: IconThemeData(color: style.foreground, size: 16),
          child: trailing!,
        ),
    ];

    final Widget surface = AnimatedOpacity(
      // `disabled:opacity-50`.
      opacity: _enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Container(
        constraints: BoxConstraints(minHeight: metrics.minHeight),
        width: size == AppButtonSize.icon ? metrics.minHeight : null,
        padding: size == AppButtonSize.icon
            ? EdgeInsets.zero
            : EdgeInsetsDirectional.symmetric(horizontal: metrics.paddingX),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: TajeerRadii.mdAll,
          border: style.border == null
              ? null
              : Border.fromBorderSide(BorderSide(color: style.border!)),
          boxShadow: style.shadow,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: TajeerSpacing.x2, // `gap-2`
          children: content,
        ),
      ),
    );

    return Pressable(
      onTap: _enabled ? onPressed : null,
      enabled: _enabled,
      borderRadius: TajeerRadii.mdAll,
      semanticLabel: semanticLabel ?? label,
      excludeSemantics: semanticLabel != null,
      // The link variant is text, not a surface: washing it would tint the
      // words rather than a background that isn't there.
      hoverStep: variant == AppButtonVariant.link
          ? ElevateStep.none
          : ElevateStep.one,
      pressStep: variant == AppButtonVariant.link
          ? ElevateStep.none
          : ElevateStep.two,
      scaleOnPress: variant != AppButtonVariant.link,
      child: expand
          ? SizedBox(width: double.infinity, child: surface)
          : surface,
    );
  }

  _ButtonStyle _style(TajeerColors colors) {
    return switch (variant) {
      AppButtonVariant.primary => _ButtonStyle(
        background: colors.primary,
        foreground: colors.primaryForeground,
        border: colors.opaqueBorderFor(colors.primary),
        shadow: TajeerShadows.none,
      ),
      AppButtonVariant.destructive => _ButtonStyle(
        background: colors.destructive,
        foreground: colors.destructiveForeground,
        border: colors.opaqueBorderFor(colors.destructive),
        shadow: TajeerShadows.xs,
      ),
      // `outline` deliberately has no background: it shows whatever card or
      // sidebar surface it was dropped onto, and inherits the text colour.
      AppButtonVariant.outline => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.foreground,
        border: colors.buttonOutline,
        shadow: TajeerShadows.xs,
      ),
      AppButtonVariant.secondary => _ButtonStyle(
        background: colors.secondary,
        foreground: colors.secondaryForeground,
        border: colors.opaqueBorderFor(colors.secondary),
        shadow: TajeerShadows.none,
      ),
      AppButtonVariant.ghost => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.foreground,
        border: Colors.transparent,
        shadow: TajeerShadows.none,
      ),
      AppButtonVariant.link => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.primary,
        border: null,
        shadow: TajeerShadows.none,
      ),
    };
  }

  _ButtonMetrics _metrics() {
    return switch (size) {
      // `min-h-9 px-4`, `text-sm`.
      AppButtonSize.medium => const _ButtonMetrics(
        minHeight: 36,
        paddingX: TajeerSpacing.x4,
        fontSize: TajeerTypography.sm,
        lineHeight: 20,
      ),
      // `min-h-8 px-3 text-xs`.
      AppButtonSize.small => const _ButtonMetrics(
        minHeight: 32,
        paddingX: TajeerSpacing.x3,
        fontSize: TajeerTypography.xs,
        lineHeight: 16,
      ),
      // `min-h-10 px-8`.
      AppButtonSize.large => const _ButtonMetrics(
        minHeight: 40,
        paddingX: TajeerSpacing.x8,
        fontSize: TajeerTypography.sm,
        lineHeight: 20,
      ),
      // `h-9 w-9`.
      AppButtonSize.icon => const _ButtonMetrics(
        minHeight: 36,
        paddingX: 0,
        fontSize: TajeerTypography.sm,
        lineHeight: 20,
      ),
    };
  }
}

@immutable
class _ButtonStyle {
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color foreground;
  final Color? border;
  final List<BoxShadow> shadow;
}

@immutable
class _ButtonMetrics {
  const _ButtonMetrics({
    required this.minHeight,
    required this.paddingX,
    required this.fontSize,
    required this.lineHeight,
  });

  final double minHeight;
  final double paddingX;
  final double fontSize;
  final double lineHeight;
}
