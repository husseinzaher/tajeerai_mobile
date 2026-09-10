import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';
import '../loaders/spinner.dart';

/// The six button variants, matching `button.tsx`'s `cva` set.
enum AppButtonVariant { primary, destructive, outline, secondary, ghost, link }

/// The four sizes: `default`, `sm`, `lg`, `icon`.
enum AppButtonSize { medium, small, large, icon }

/// The system's button.
///
/// A direct port of the design system's `Button`: same variants, same sizes,
/// same `rounded-md` corner, and the same interaction model -- no hover colour
/// per variant, just the shared elevate overlay from [AppPressable]. The border
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
    final style = _style(colors, context.elevation);
    final metrics = _metrics();

    final content = <Widget>[
      if (loading)
        AppSpinner(size: 16, color: style.foreground)
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
            style: _label(context).copyWith(
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
          spacing: TajeerSpacing.xs, // `gap-2`
          children: content,
        ),
      ),
    );

    return AppPressable(
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

  /// The label step for this size. Control labels are the `label*` family:
  /// tighter leading than body, because a button label is one line by design.
  TextStyle _label(BuildContext context) => switch (size) {
    AppButtonSize.small => context.type.labelMd,
    _ => context.type.labelLg,
  };

  _ButtonStyle _style(TajeerColors colors, TajeerElevations elevations) {
    return switch (variant) {
      AppButtonVariant.primary => _ButtonStyle(
        background: colors.primary,
        foreground: colors.primaryForeground,
        border: colors.primaryBorder,
        shadow: const <BoxShadow>[],
      ),
      AppButtonVariant.destructive => _ButtonStyle(
        background: colors.dangerDefault,
        foreground: colors.textInverse,
        border: colors.dangerDefault,
        shadow: elevations.subtle.shadow,
      ),
      // `outline` deliberately has no background: it shows whatever card or
      // sidebar surface it was dropped onto, and inherits the text colour.
      AppButtonVariant.outline => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.textPrimary,
        border: colors.border,
        shadow: elevations.subtle.shadow,
      ),
      AppButtonVariant.secondary => _ButtonStyle(
        background: colors.surfaceMuted,
        foreground: colors.textPrimary,
        border: colors.border,
        shadow: const <BoxShadow>[],
      ),
      AppButtonVariant.ghost => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.textPrimary,
        border: Colors.transparent,
        shadow: const <BoxShadow>[],
      ),
      // `focus`, not `primary`. In the Tajeer light palette the brand yellow
      // is 1.53:1 on white -- it is a fill, and there is no legal way to draw
      // text in it. `focus` is the brand-family colour that carries text.
      AppButtonVariant.link => _ButtonStyle(
        background: Colors.transparent,
        foreground: colors.focus,
        border: null,
        shadow: const <BoxShadow>[],
      ),
    };
  }

  _ButtonMetrics _metrics() {
    return switch (size) {
      // Every height here is a MINIMUM, never a fixed height: the label grows
      // with the OS text size, and a control that clips scaled text is an
      // accessibility bug. 44 is the platform touch-target floor, which the
      // previous 36 and 32 did not meet.
      AppButtonSize.medium => const _ButtonMetrics(
        minHeight: 44,
        paddingX: TajeerSpacing.md,
      ),
      AppButtonSize.small => const _ButtonMetrics(
        minHeight: 36,
        paddingX: TajeerSpacing.sm,
      ),
      // The reference draws the primary call to action taller than a default
      // control, and gives it the full width of its column.
      AppButtonSize.large => const _ButtonMetrics(
        minHeight: 52,
        paddingX: TajeerSpacing.xl,
      ),
      AppButtonSize.icon => const _ButtonMetrics(minHeight: 44, paddingX: 0),
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
  const _ButtonMetrics({required this.minHeight, required this.paddingX});

  /// A minimum, never a fixed height: the label grows with the OS text size.
  final double minHeight;
  final double paddingX;
}
