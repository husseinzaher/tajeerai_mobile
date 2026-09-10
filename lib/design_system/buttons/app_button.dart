import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';
import '../loaders/spinner.dart';

/// The six button variants, matching `button.tsx`'s `cva` set.
enum AppButtonVariant {
  primary,
  destructive,
  outline,
  secondary,

  /// The brand at wash strength: a call to action that is *available* rather
  /// than the one thing to do. Distinct from `secondary`, which is neutral —
  /// this one still says "brand", quietly.
  soft,

  ghost,
  link,
}

/// Whether the button is a rounded rectangle or a circle.
///
/// A circle is for a single glyph with nothing beside it — a composer's send,
/// a floating action. It is a shape, not a variant, so any variant can wear it.
enum AppButtonShape { rounded, circle }

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
    this.shape = AppButtonShape.rounded,
    this.badge,
    super.key,
  });

  /// Icon-only. [semanticLabel] is required because there is no text to read.
  const AppButton.icon({
    required Widget icon,
    required String this.semanticLabel,
    this.onPressed,
    this.variant = AppButtonVariant.ghost,
    this.loading = false,
    this.shape = AppButtonShape.rounded,
    this.badge,
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
  final AppButtonShape shape;

  /// A marker at the top-end corner — an unread dot on a notifications icon, a
  /// count on a tab. Positioned directionally, so it sits top-left in Arabic.
  ///
  /// This is why there is no `NotificationButton`: it is this button with a
  /// badge, and a separate class would be a second thing to restyle.
  final Widget? badge;

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
      duration: context.motion.fast,
      child: Container(
        constraints: BoxConstraints(minHeight: metrics.minHeight),
        width: size == AppButtonSize.icon ? metrics.minHeight : null,
        padding: size == AppButtonSize.icon
            ? EdgeInsets.zero
            : EdgeInsetsDirectional.symmetric(horizontal: metrics.paddingX),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: _radius,
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

    final Widget marked = badge == null
        ? surface
        : Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              surface,
              // Directional, so it lands top-left in Arabic. A `Positioned`
              // with `right:` would pin it to the same physical corner in both
              // languages, which is the corner it does not belong in for one
              // of them.
              PositionedDirectional(
                top: -TajeerSpacing.xs2,
                end: -TajeerSpacing.xs2,
                child: badge!,
              ),
            ],
          );

    return AppPressable(
      onTap: _enabled ? onPressed : null,
      enabled: _enabled,
      borderRadius: _radius,
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
      child: expand ? SizedBox(width: double.infinity, child: marked) : marked,
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
      AppButtonVariant.soft => _ButtonStyle(
        background: colors.primarySoft,
        // `focus`, not `primary`: in the light palette the accent is a fill and
        // cannot carry text. See the `link` variant below.
        foreground: colors.focus,
        border: Colors.transparent,
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

  BorderRadius get _radius => switch (shape) {
    AppButtonShape.rounded => TajeerRadii.mdAll,
    AppButtonShape.circle => TajeerRadii.fullAll,
  };

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
