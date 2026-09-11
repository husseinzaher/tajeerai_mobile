import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.g.dart';
import 'typography.dart';

/// Builds a [ThemeData] for one preset in one brightness.
///
/// Four combinations today — two presets, two brightnesses — and no component
/// knows which one it is in. Material's own component themes are pointed at the
/// same semantic names the design system uses, so a stock widget that slips
/// into a screen inherits the product's surfaces rather than Material's purple
/// defaults. Design-system widgets read [TajeerColors] and the other extensions
/// directly; the [ColorScheme] exists for the Material widgets underneath them.
abstract final class AppTheme {
  static ThemeData light({TajeerPreset preset = TajeerPreset.fallback}) =>
      _build(preset, Brightness.light);

  static ThemeData dark({TajeerPreset preset = TajeerPreset.fallback}) =>
      _build(preset, Brightness.dark);

  /// The one entry point that takes both axes, for a caller that already holds
  /// a resolved brightness — the showcase, and any test pumping a matrix.
  static ThemeData of(TajeerPreset preset, Brightness brightness) =>
      _build(preset, brightness);

  static ThemeData _build(TajeerPreset preset, Brightness brightness) {
    final TajeerPalette palette = TajeerPalette.of(preset, brightness);
    final TajeerColors colors = palette.colors;
    final TajeerElevations elevations = palette.elevations;
    final TajeerTypeScale type = palette.type;
    final TajeerChannelColors channels = brightness == Brightness.dark
        ? TajeerChannelColors.dark
        : TajeerChannelColors.light;

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryForeground,
      primaryContainer: colors.primarySoft,
      onPrimaryContainer: colors.textPrimary,
      secondary: colors.surfaceMuted,
      onSecondary: colors.textPrimary,
      tertiary: colors.infoDefault,
      onTertiary: colors.textInverse,
      error: colors.dangerDefault,
      onError: colors.textInverse,
      surface: colors.background,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceMuted,
      onSurfaceVariant: colors.textMuted,
      outline: colors.border,
      outlineVariant: colors.borderSubtle,
    );

    // The family goes on here and not only on `ThemeData`. `fontFamily:` below
    // reaches `ThemeData.textTheme`, but not a style copied out of this local
    // theme into a component theme — and `AppBar` and `SnackBar` *replace* the
    // inherited text style with their component theme's. Without this, text
    // inside a toolbar lost the typeface and fell back to the platform's.
    final TextTheme textTheme = TajeerTypography.textTheme(type).apply(
      fontFamily: TajeerTypography.sansFamily,
      fontFamilyFallback: TajeerTypography.sansFallback,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[colors, channels, type, elevations],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.border,
      textTheme: textTheme,
      fontFamily: TajeerTypography.sansFamily,
      fontFamilyFallback: TajeerTypography.sansFallback,
      splashFactory: NoSplash.splashFactory,
      // Press feedback is the overlay plus a scale, and both live in
      // `AppPressable`. Material's ink ripple on top would be a second, different
      // press animation.
      highlightColor: Colors.transparent,
      hoverColor: colors.overlayHover,
      focusColor: colors.focus.withValues(alpha: 0.4),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: elevations.card.tone,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.lgAll,
          side: BorderSide(color: elevations.card.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevations.modal.tone,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.xlAll,
          side: BorderSide(color: elevations.modal.hairline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevations.modal.tone,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: colors.surfaceOverlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TajeerRadii.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevations.popover.tone,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.lgAll,
          side: BorderSide(color: elevations.popover.hairline),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      iconTheme: IconThemeData(color: colors.textPrimary, size: 20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Reaches the theme's extensions without spelling out the lookup at every call
/// site. `context.colors.primary` is this codebase's `bg-primary`.
///
/// Each getter falls back to the default preset's light values rather than
/// throwing, so a widget pumped in a bare test tree still renders.
extension TajeerThemeContext on BuildContext {
  TajeerColors get colors =>
      Theme.of(this).extension<TajeerColors>() ?? TajeerColors.tajeerLight;

  /// The fourteen-step scale, ink already applied.
  TajeerTypeScale get type =>
      Theme.of(this).extension<TajeerTypeScale>() ??
      TajeerTypeScale.tajeerLight;

  /// The six depth levels: tone, hairline and shadow together.
  TajeerElevations get elevation =>
      Theme.of(this).extension<TajeerElevations>() ??
      TajeerElevations.tajeerLight;

  /// The named channel identities, shared by every preset.
  TajeerChannelColors get channels =>
      Theme.of(this).extension<TajeerChannelColors>() ??
      TajeerChannelColors.light;

  /// Material's own text theme. Prefer [type]: it is the product's scale, and
  /// this is what Material widgets underneath it read.
  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
