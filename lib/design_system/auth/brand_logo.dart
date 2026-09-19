import 'package:flutter/material.dart';

/// Which of the logo system's forms to draw.
enum AppBrandLogoVariant {
  /// The gradient T and its arrow, alone — the sign-in screen, a toolbar, a
  /// drawer header, an avatar-sized slot.
  mark,

  /// The mark above the wordmark.
  vertical,

  /// The mark beside the wordmark — for a wide, short space.
  horizontal,
}

/// The Tajeer AI logo, drawn from the brand's own exports.
///
/// Nothing here draws a logo of its own. The images are generated from the
/// official files in `assets/brand/` by `assets/brand/build_app_assets.py` —
/// trimmed and downscaled, never redrawn — and `assets/brand/README.md` says
/// where each came from.
///
/// Which file is drawn is decided once, here, rather than at every call site.
/// The vertical logo comes in four, because its wordmark is set in Arabic or in
/// Latin, and in yellow for a light canvas or white for a dark one. The
/// horizontal logo and the mark read on both canvases, so each comes in one.
///
/// It never mirrors. A logo is a fixed graphic, not a sentence: an Arabic screen
/// shows it exactly as an English one does, which is why
/// [Image.matchTextDirection] is left off.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    this.variant = AppBrandLogoVariant.vertical,
    this.height,
    this.name = 'Tajeer AI',
    super.key,
  });

  final AppBrandLogoVariant variant;

  /// How tall to draw it; the width follows from the artwork's proportions.
  /// Null picks a height suited to the variant.
  final double? height;

  /// What a screen reader calls the whole logo.
  final String name;

  static const String _directory = 'assets/brand/app';

  static const String markAsset = '$_directory/mark.png';
  static const String horizontalAsset = '$_directory/lockup_horizontal.png';
  static const String verticalEnLight = '$_directory/lockup_en_light.png';
  static const String verticalEnDark = '$_directory/lockup_en_dark.png';
  static const String verticalArLight = '$_directory/lockup_ar_light.png';
  static const String verticalArDark = '$_directory/lockup_ar_dark.png';

  /// Every file this component can draw.
  static const List<String> assets = <String>[
    markAsset,
    horizontalAsset,
    verticalEnLight,
    verticalEnDark,
    verticalArLight,
    verticalArDark,
  ];

  /// The file for a variant, in a language, on a canvas.
  ///
  /// Pure, so the choice is testable without drawing anything. Only Arabic has a
  /// wordmark of its own; every other language reads the Latin one.
  static String assetFor(
    AppBrandLogoVariant variant, {
    required Brightness brightness,
    required String languageCode,
  }) {
    final bool dark = brightness == Brightness.dark;
    return switch (variant) {
      AppBrandLogoVariant.mark => markAsset,
      AppBrandLogoVariant.horizontal => horizontalAsset,
      AppBrandLogoVariant.vertical when languageCode == 'ar' =>
        dark ? verticalArDark : verticalArLight,
      AppBrandLogoVariant.vertical => dark ? verticalEnDark : verticalEnLight,
    };
  }

  static double _defaultHeight(AppBrandLogoVariant variant) =>
      switch (variant) {
        AppBrandLogoVariant.mark => 56,
        AppBrandLogoVariant.vertical => 112,
        AppBrandLogoVariant.horizontal => 36,
      };

  @override
  Widget build(BuildContext context) {
    final double drawn = height ?? _defaultHeight(variant);
    final double pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final String asset = assetFor(
      variant,
      brightness: Theme.of(context).brightness,
      languageCode: Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
    );

    return Semantics(
      container: true,
      image: true,
      label: name,
      child: Image.asset(
        asset,
        height: drawn,
        fit: BoxFit.contain,
        // Decoded at the size it is drawn rather than the export's: a 600px
        // lockup shown 112 points tall should not hold 600px of image.
        cacheHeight: (drawn * pixelRatio).round(),
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        // A logo that fails to load must not take the screen's layout with it.
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            SizedBox(height: drawn),
      ),
    );
  }
}
