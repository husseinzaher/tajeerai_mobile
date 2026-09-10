import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// The typeface, and how the fourteen-step scale meets Material's fifteen.
///
/// The scale itself is generated — sizes, heights, weights and ink live in
/// `design/tokens.json`. What stays here is the part that is a judgement rather
/// than a value: which face, which fallbacks, which Material slot each step
/// belongs in, and how far text is allowed to scale before a layout stops
/// meaning anything.
abstract final class TajeerTypography {
  /// Bundled at `assets/fonts/`, not fetched. See that directory's README for
  /// why three weights and why no 600.
  static const String sansFamily = 'Tajawal';

  /// Tajawal covers Arabic and Latin in one face, so mixed content renders
  /// without falling through. These are for what it does not have: CJK in a
  /// customer's name, emoji, rarer presentation forms.
  static const List<String> sansFallback = <String>[
    'Noto Sans Arabic',
    'Roboto',
    'SF Pro Text',
  ];

  /// The ceiling on OS text scaling, applied once in `TajeerApp`.
  ///
  /// iOS offers roughly 3.1x. Past 2x a conversation list stops being a list —
  /// two rows fill the screen and the rail no longer answers the question it
  /// exists for.
  static const double maxTextScale = 2;

  /// A tighter ceiling for controls whose height is a design constant.
  ///
  /// Applied to the label subtree of a button, a toolbar title, a tab. It
  /// bounds the growth; it does not license clipping — the layout still has to
  /// survive at this scale, which the showcase smoke test checks.
  static const double controlMaxScale = 1.3;

  /// Wraps [child] in the control ceiling.
  static Widget clampForControl(Widget child) =>
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: controlMaxScale,
        child: child,
      );

  /// Maps the scale onto Material's slots.
  ///
  /// Not a bijection, and pretending otherwise is how a scale acquires a
  /// fifteenth step nobody designed. Two Material slots double up on a step,
  /// and `caption` has no Material home at all — it is reached as
  /// `context.type.caption`.
  ///
  /// This exists so a stray `Text` with no style lands on the product's scale
  /// instead of Material's.
  static TextTheme textTheme(TajeerTypeScale scale) => TextTheme(
    displayLarge: scale.display,
    displayMedium: scale.headlineXl,
    displaySmall: scale.headlineLg,
    headlineLarge: scale.headlineLg,
    headlineMedium: scale.headlineMd,
    headlineSmall: scale.titleLg,
    titleLarge: scale.titleLg,
    titleMedium: scale.titleMd,
    titleSmall: scale.titleSm,
    bodyLarge: scale.bodyLg,
    bodyMedium: scale.bodyMd,
    bodySmall: scale.bodySm,
    labelLarge: scale.labelLg,
    labelMedium: scale.labelMd,
    labelSmall: scale.labelSm,
  );
}
