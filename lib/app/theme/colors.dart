import 'package:flutter/material.dart';

/// The semantic colour palette, transcribed from
/// `packages/tajeerai-design-system/tokens.json`.
///
/// The web theme remaps one set of semantic names across light and dark rather
/// than exposing raw hexes, and this extension is the same contract for
/// Flutter: a widget asks for [TajeerColors.primary], never for `#4f46e5`, so
/// it cannot be wrong in one of the two appearances.
///
/// Values are copied by hand because the generator emits CSS and a TypeScript
/// map, neither of which Dart can read at build time. `tokens_parity_test.dart`
/// checks them back against `tokens.json` so a drifted colour fails the suite
/// rather than shipping.
@immutable
class TajeerColors extends ThemeExtension<TajeerColors> {
  const TajeerColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.primaryStrong,
    required this.primaryMuted,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
    required this.input,
    required this.ring,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarMutedForeground,
    required this.sidebarBorder,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarInset,
    required this.sidebarActive,
    required this.sidebarRing,
    required this.elevate1,
    required this.elevate2,
    required this.buttonOutline,
    required this.badgeOutline,
    required this.opaqueButtonBorderIntensity,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color primaryStrong;
  final Color primaryMuted;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;
  final Color input;
  final Color ring;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarMutedForeground;
  final Color sidebarBorder;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarInset;
  final Color sidebarActive;
  final Color sidebarRing;

  /// The hover/press wash the web theme paints *over* a surface rather than
  /// swapping the surface colour. Keeping it as an overlay is what lets one
  /// pressable work on `card`, `sidebar` and `primary` alike.
  final Color elevate1;
  final Color elevate2;

  /// Hairline on outline buttons and badges: a translucent black in light, a
  /// translucent white in dark, so it reads against whatever it sits on.
  final Color buttonOutline;
  final Color badgeOutline;

  /// Lightness shift, in percentage points, that derives the contrast border
  /// drawn around an opaque button. Negative darkens (light theme), positive
  /// lightens (dark theme) -- mirroring `--opaque-button-border-intensity`.
  final double opaqueButtonBorderIntensity;

  /// The border the web theme computes for an opaque surface, rather than
  /// storing a second colour per variant.
  Color opaqueBorderFor(Color surface) {
    final hsl = HSLColor.fromColor(surface);
    final lightness = (hsl.lightness + opaqueButtonBorderIntensity / 100).clamp(
      0.0,
      1.0,
    );

    return hsl.withLightness(lightness).toColor();
  }

  static const TajeerColors light = TajeerColors(
    background: Color(0xFFF4F4F5),
    foreground: Color(0xFF353535),
    border: Color(0xFFE4E4E7),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF353535),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF353535),
    primary: Color(0xFF4F46E5),
    primaryForeground: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFF4338CA),
    primaryMuted: Color(0xFFEEF2FF),
    secondary: Color(0xFFF3F4F6),
    secondaryForeground: Color(0xFF454545),
    muted: Color(0xFFF3F4F6),
    mutedForeground: Color(0xFF6C7078),
    accent: Color(0xFF06B6D4),
    accentForeground: Color(0xFF083344),
    destructive: Color(0xFFDC5B4D),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF00AA6F),
    successForeground: Color(0xFFF6FEF9),
    warning: Color(0xFFEBAA2D),
    warningForeground: Color(0xFF392400),
    input: Color(0xFFE4E4E7),
    ring: Color(0xFF4F46E5),
    chart1: Color(0xFF4F46E5),
    chart2: Color(0xFF06B6D4),
    chart3: Color(0xFF7C3AED),
    chart4: Color(0xFFDB2777),
    chart5: Color(0xFF65A30D),
    sidebar: Color(0xFFE4E7EC),
    sidebarForeground: Color(0xFF1A1D22),
    sidebarMutedForeground: Color(0xFF5F6975),
    sidebarBorder: Color(0xFFCFD4DC),
    sidebarPrimary: Color(0xFF3A5568),
    sidebarPrimaryForeground: Color(0xFFFFFFFF),
    sidebarAccent: Color(0xFFD8DCE3),
    sidebarAccentForeground: Color(0xFF1A1D22),
    sidebarInset: Color(0xFFDCE0E6),
    sidebarActive: Color(0xFFD3DDE6),
    sidebarRing: Color(0xFF4F46E5),
    elevate1: Color(0x08000000), // rgba(0,0,0,.03)
    elevate2: Color(0x14000000), // rgba(0,0,0,.08)
    buttonOutline: Color(0x1A000000), // rgba(0,0,0,.10)
    badgeOutline: Color(0x0D000000), // rgba(0,0,0,.05)
    opaqueButtonBorderIntensity: -8,
  );

  static const TajeerColors dark = TajeerColors(
    background: Color(0xFF2C2D2F),
    foreground: Color(0xFFFFFFFF),
    border: Color(0xFF3A3B3E),
    card: Color(0xFF2A2B2D),
    cardForeground: Color(0xFFFFFFFF),
    popover: Color(0xFF2A2B2D),
    popoverForeground: Color(0xFFFFFFFF),
    primary: Color(0xFF6366F1),
    primaryForeground: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFF4F46E5),
    primaryMuted: Color(0xFF2A2550),
    secondary: Color(0xFF35363A),
    secondaryForeground: Color(0xFFFFFFFF),
    muted: Color(0xFF35363A),
    mutedForeground: Color(0xFF919293),
    accent: Color(0xFF22D3EE),
    accentForeground: Color(0xFF083344),
    destructive: Color(0xFFD86A5C),
    destructiveForeground: Color(0xFFFFFFFF),
    success: Color(0xFF37B880),
    successForeground: Color(0xFF021109),
    warning: Color(0xFFEFB146),
    warningForeground: Color(0xFF211300),
    input: Color(0xFF3A3B3E),
    ring: Color(0xFF6366F1),
    chart1: Color(0xFF818CF8),
    chart2: Color(0xFF22D3EE),
    chart3: Color(0xFFA78BFA),
    chart4: Color(0xFFF472B6),
    chart5: Color(0xFFA3E635),
    sidebar: Color(0xFF16181D),
    sidebarForeground: Color(0xFFECEEF1),
    sidebarMutedForeground: Color(0xFF8B929C),
    sidebarBorder: Color(0xFF2A2E35),
    sidebarPrimary: Color(0xFF8FA4B8),
    sidebarPrimaryForeground: Color(0xFFFFFFFF),
    sidebarAccent: Color(0xFF22262C),
    sidebarAccentForeground: Color(0xFFECEEF1),
    sidebarInset: Color(0xFF121418),
    sidebarActive: Color(0xFF2A3038),
    sidebarRing: Color(0xFF6366F1),
    elevate1: Color(0x0AFFFFFF), // rgba(255,255,255,.04)
    elevate2: Color(0x17FFFFFF), // rgba(255,255,255,.09)
    buttonOutline: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
    badgeOutline: Color(0x0DFFFFFF), // rgba(255,255,255,.05)
    opaqueButtonBorderIntensity: 9,
  );

  @override
  TajeerColors copyWith({
    Color? background,
    Color? foreground,
    Color? border,
    Color? card,
    Color? cardForeground,
    Color? popover,
    Color? popoverForeground,
    Color? primary,
    Color? primaryForeground,
    Color? primaryStrong,
    Color? primaryMuted,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? success,
    Color? successForeground,
    Color? warning,
    Color? warningForeground,
    Color? input,
    Color? ring,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? sidebar,
    Color? sidebarForeground,
    Color? sidebarMutedForeground,
    Color? sidebarBorder,
    Color? sidebarPrimary,
    Color? sidebarPrimaryForeground,
    Color? sidebarAccent,
    Color? sidebarAccentForeground,
    Color? sidebarInset,
    Color? sidebarActive,
    Color? sidebarRing,
    Color? elevate1,
    Color? elevate2,
    Color? buttonOutline,
    Color? badgeOutline,
    double? opaqueButtonBorderIntensity,
  }) {
    return TajeerColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      border: border ?? this.border,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      popover: popover ?? this.popover,
      popoverForeground: popoverForeground ?? this.popoverForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground:
          destructiveForeground ?? this.destructiveForeground,
      success: success ?? this.success,
      successForeground: successForeground ?? this.successForeground,
      warning: warning ?? this.warning,
      warningForeground: warningForeground ?? this.warningForeground,
      input: input ?? this.input,
      ring: ring ?? this.ring,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
      sidebar: sidebar ?? this.sidebar,
      sidebarForeground: sidebarForeground ?? this.sidebarForeground,
      sidebarMutedForeground:
          sidebarMutedForeground ?? this.sidebarMutedForeground,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarPrimary: sidebarPrimary ?? this.sidebarPrimary,
      sidebarPrimaryForeground:
          sidebarPrimaryForeground ?? this.sidebarPrimaryForeground,
      sidebarAccent: sidebarAccent ?? this.sidebarAccent,
      sidebarAccentForeground:
          sidebarAccentForeground ?? this.sidebarAccentForeground,
      sidebarInset: sidebarInset ?? this.sidebarInset,
      sidebarActive: sidebarActive ?? this.sidebarActive,
      sidebarRing: sidebarRing ?? this.sidebarRing,
      elevate1: elevate1 ?? this.elevate1,
      elevate2: elevate2 ?? this.elevate2,
      buttonOutline: buttonOutline ?? this.buttonOutline,
      badgeOutline: badgeOutline ?? this.badgeOutline,
      opaqueButtonBorderIntensity:
          opaqueButtonBorderIntensity ?? this.opaqueButtonBorderIntensity,
    );
  }

  @override
  TajeerColors lerp(covariant TajeerColors? other, double t) {
    if (other == null) return this;

    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return TajeerColors(
      background: mix(background, other.background),
      foreground: mix(foreground, other.foreground),
      border: mix(border, other.border),
      card: mix(card, other.card),
      cardForeground: mix(cardForeground, other.cardForeground),
      popover: mix(popover, other.popover),
      popoverForeground: mix(popoverForeground, other.popoverForeground),
      primary: mix(primary, other.primary),
      primaryForeground: mix(primaryForeground, other.primaryForeground),
      primaryStrong: mix(primaryStrong, other.primaryStrong),
      primaryMuted: mix(primaryMuted, other.primaryMuted),
      secondary: mix(secondary, other.secondary),
      secondaryForeground: mix(secondaryForeground, other.secondaryForeground),
      muted: mix(muted, other.muted),
      mutedForeground: mix(mutedForeground, other.mutedForeground),
      accent: mix(accent, other.accent),
      accentForeground: mix(accentForeground, other.accentForeground),
      destructive: mix(destructive, other.destructive),
      destructiveForeground: mix(
        destructiveForeground,
        other.destructiveForeground,
      ),
      success: mix(success, other.success),
      successForeground: mix(successForeground, other.successForeground),
      warning: mix(warning, other.warning),
      warningForeground: mix(warningForeground, other.warningForeground),
      input: mix(input, other.input),
      ring: mix(ring, other.ring),
      chart1: mix(chart1, other.chart1),
      chart2: mix(chart2, other.chart2),
      chart3: mix(chart3, other.chart3),
      chart4: mix(chart4, other.chart4),
      chart5: mix(chart5, other.chart5),
      sidebar: mix(sidebar, other.sidebar),
      sidebarForeground: mix(sidebarForeground, other.sidebarForeground),
      sidebarMutedForeground: mix(
        sidebarMutedForeground,
        other.sidebarMutedForeground,
      ),
      sidebarBorder: mix(sidebarBorder, other.sidebarBorder),
      sidebarPrimary: mix(sidebarPrimary, other.sidebarPrimary),
      sidebarPrimaryForeground: mix(
        sidebarPrimaryForeground,
        other.sidebarPrimaryForeground,
      ),
      sidebarAccent: mix(sidebarAccent, other.sidebarAccent),
      sidebarAccentForeground: mix(
        sidebarAccentForeground,
        other.sidebarAccentForeground,
      ),
      sidebarInset: mix(sidebarInset, other.sidebarInset),
      sidebarActive: mix(sidebarActive, other.sidebarActive),
      sidebarRing: mix(sidebarRing, other.sidebarRing),
      elevate1: mix(elevate1, other.elevate1),
      elevate2: mix(elevate2, other.elevate2),
      buttonOutline: mix(buttonOutline, other.buttonOutline),
      badgeOutline: mix(badgeOutline, other.badgeOutline),
      opaqueButtonBorderIntensity:
          opaqueButtonBorderIntensity +
          (other.opaqueButtonBorderIntensity - opaqueButtonBorderIntensity) * t,
    );
  }
}
