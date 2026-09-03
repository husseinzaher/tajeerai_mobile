import 'package:flutter/material.dart';

/// The type scale and families, from `tokens.json`'s `typography` group and
/// the `--text-*` steps the web theme declares.
///
/// Each step pairs a size with the line height the web theme computes for it
/// (`--text-sm--line-height: calc(1.25 / 0.875)`), expressed here as Flutter's
/// multiplier-style [TextStyle.height] -- the same ratio, so a label lifted
/// from a `.tsx` file occupies the same vertical space.
abstract final class TajeerTypography {
  /// `typography.fontFamily.sans`. Arabic-first, with the Latin fallback the
  /// token names.
  ///
  /// The family is requested by name and the fallbacks carry the rendering
  /// until the face ships as a bundled asset -- see `pubspec.yaml`. On a device
  /// without it, `fontFamilyFallback` resolves to the platform UI face rather
  /// than to a serif default.
  static const String sansFamily = 'IBM Plex Sans Arabic';

  static const List<String> sansFallback = <String>[
    'Inter',
    'Segoe UI',
    'Roboto',
    'SF Pro Text',
  ];

  static const String monoFamily = 'Menlo';
  static const List<String> monoFallback = <String>['Roboto Mono', 'monospace'];

  // Sizes -- the `--text-*` steps.
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 30;
  static const double xl4 = 36;

  // Weights the components use: `font-medium`, `font-semibold`, `font-bold`.
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  static TextStyle _style(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: sansFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
    );
  }

  /// The scale as a Material [TextTheme].
  ///
  /// Material's slot names are mapped onto the web steps rather than left at
  /// their defaults, so a stray `Text` with no explicit style still lands on
  /// the system's scale instead of Material's.
  static TextTheme textTheme(Color foreground) {
    final theme = TextTheme(
      displayLarge: _style(xl4, 40, bold),
      displayMedium: _style(xl3, 36, bold),
      displaySmall: _style(xl2, 32, semibold),
      headlineLarge: _style(xl2, 32, semibold),
      headlineMedium: _style(xl, 28, semibold),
      headlineSmall: _style(lg, 28, semibold),
      titleLarge: _style(lg, 28, semibold),
      titleMedium: _style(base, 24, medium),
      titleSmall: _style(sm, 20, medium),
      bodyLarge: _style(base, 24, regular),
      bodyMedium: _style(sm, 20, regular),
      bodySmall: _style(xs, 16, regular),
      labelLarge: _style(sm, 20, medium),
      labelMedium: _style(xs, 16, medium),
      labelSmall: _style(xs, 16, medium),
    );

    return theme.apply(bodyColor: foreground, displayColor: foreground);
  }
}
