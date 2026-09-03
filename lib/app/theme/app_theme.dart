import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'motion.dart';
import 'radii.dart';
import 'typography.dart';

/// Builds the two [ThemeData]s from the token set.
///
/// Material's own component themes are pointed at the same semantic names the
/// design system uses, so a stock widget that slips into a screen inherits the
/// product's surfaces instead of Material's purple defaults. Widgets in
/// `design_system/` read [TajeerColors] directly rather than going through
/// [ColorScheme]; the scheme exists for the Material widgets underneath them.
abstract final class AppTheme {
  static ThemeData light() => _build(TajeerColors.light, Brightness.light);

  static ThemeData dark() => _build(TajeerColors.dark, Brightness.dark);

  static ThemeData _build(TajeerColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryForeground,
      primaryContainer: colors.primaryMuted,
      onPrimaryContainer: colors.foreground,
      secondary: colors.secondary,
      onSecondary: colors.secondaryForeground,
      tertiary: colors.accent,
      onTertiary: colors.accentForeground,
      error: colors.destructive,
      onError: colors.destructiveForeground,
      surface: colors.background,
      onSurface: colors.foreground,
      surfaceContainerHighest: colors.muted,
      onSurfaceVariant: colors.mutedForeground,
      outline: colors.border,
      outlineVariant: colors.border,
    );

    final textTheme = TajeerTypography.textTheme(colors.foreground);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.border,
      textTheme: textTheme,
      fontFamily: TajeerTypography.sansFamily,
      fontFamilyFallback: TajeerTypography.sansFallback,
      splashFactory: NoSplash.splashFactory,
      // The web theme expresses press feedback as the `elevate` overlay plus a
      // scale, and both live in `Pressable`. Material's ink ripple on top of
      // that would be a second, different press animation.
      highlightColor: Colors.transparent,
      hoverColor: colors.elevate1,
      focusColor: colors.ring.withValues(alpha: 0.4),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.xlAll,
          side: BorderSide(color: colors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.lgAll,
          side: BorderSide(color: colors.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: const Color(0xCC000000), // bg-black/80
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TajeerRadii.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.popover,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.popoverForeground,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.lgAll,
          side: BorderSide(color: colors.border),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.muted,
        circularTrackColor: Colors.transparent,
      ),
      iconTheme: IconThemeData(color: colors.foreground, size: 16),
      // `[&_svg]:size-4` -- lucide icons render at 16px inside controls.
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

  /// Default transition timing for anything animating outside a component.
  static const Duration transition = TajeerMotion.duration;
}

/// Reaches the palette without spelling out the extension lookup at every call
/// site. `context.colors.primary` is the Flutter spelling of `bg-primary`.
extension TajeerThemeContext on BuildContext {
  TajeerColors get colors =>
      Theme.of(this).extension<TajeerColors>() ?? TajeerColors.light;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
