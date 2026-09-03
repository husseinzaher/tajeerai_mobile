import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/app_theme.dart';
import 'package:tajeerai_mobile/app/theme/colors.dart';
import 'package:tajeerai_mobile/app/theme/radii.dart';
import 'package:tajeerai_mobile/app/theme/spacing.dart';

/// Checks the Flutter palette against the design system's own `tokens.json`.
///
/// The colours in `colors.dart` are transcribed by hand, because the token
/// generator emits CSS and a TypeScript map and Dart can read neither at build
/// time. This is what stops that transcription drifting: change a colour
/// upstream without updating the app and the suite fails, rather than the two
/// platforms quietly diverging.
///
/// Skipped when `tokens.json` is not reachable -- the mobile app is a
/// submodule and can legitimately be checked out on its own, in which case
/// there is nothing to compare against and failing would be noise.
void main() {
  final tokensFile = File('../packages/tajeerai-design-system/tokens.json');
  final hasTokens = tokensFile.existsSync();

  Map<String, Object?> readGroup(String appearance) {
    final json = jsonDecode(tokensFile.readAsStringSync());
    final colors =
        (json as Map<String, Object?>)['color']! as Map<String, Object?>;

    return colors[appearance]! as Map<String, Object?>;
  }

  Color parseHex(String hex) {
    final value = hex.replaceFirst('#', '');

    return Color(int.parse('FF$value', radix: 16));
  }

  /// The token key for each field of [TajeerColors].
  Map<String, Color Function(TajeerColors)> readers() {
    return <String, Color Function(TajeerColors)>{
      'background': (c) => c.background,
      'foreground': (c) => c.foreground,
      'border': (c) => c.border,
      'card': (c) => c.card,
      'cardForeground': (c) => c.cardForeground,
      'popover': (c) => c.popover,
      'popoverForeground': (c) => c.popoverForeground,
      'primary': (c) => c.primary,
      'primaryForeground': (c) => c.primaryForeground,
      'primaryStrong': (c) => c.primaryStrong,
      'primaryMuted': (c) => c.primaryMuted,
      'secondary': (c) => c.secondary,
      'secondaryForeground': (c) => c.secondaryForeground,
      'muted': (c) => c.muted,
      'mutedForeground': (c) => c.mutedForeground,
      'accent': (c) => c.accent,
      'accentForeground': (c) => c.accentForeground,
      'destructive': (c) => c.destructive,
      'destructiveForeground': (c) => c.destructiveForeground,
      'success': (c) => c.success,
      'successForeground': (c) => c.successForeground,
      'warning': (c) => c.warning,
      'warningForeground': (c) => c.warningForeground,
      'input': (c) => c.input,
      'ring': (c) => c.ring,
      'chart1': (c) => c.chart1,
      'chart2': (c) => c.chart2,
      'chart3': (c) => c.chart3,
      'chart4': (c) => c.chart4,
      'chart5': (c) => c.chart5,
      'sidebar': (c) => c.sidebar,
      'sidebarForeground': (c) => c.sidebarForeground,
      'sidebarMutedForeground': (c) => c.sidebarMutedForeground,
      'sidebarBorder': (c) => c.sidebarBorder,
      'sidebarPrimary': (c) => c.sidebarPrimary,
      'sidebarPrimaryForeground': (c) => c.sidebarPrimaryForeground,
      'sidebarAccent': (c) => c.sidebarAccent,
      'sidebarAccentForeground': (c) => c.sidebarAccentForeground,
      'sidebarInset': (c) => c.sidebarInset,
      'sidebarActive': (c) => c.sidebarActive,
      'sidebarRing': (c) => c.sidebarRing,
    };
  }

  group(
    'token parity with the design system',
    () {
      test('every light colour matches tokens.json', () {
        final group = readGroup('light');

        readers().forEach((key, read) {
          final token = group[key]! as Map<String, Object?>;
          final expected = parseHex(token[r'$value']! as String);

          expect(
            read(TajeerColors.light),
            expected,
            reason: 'light.$key drifted from tokens.json',
          );
        });
      });

      test('every dark colour matches tokens.json', () {
        final group = readGroup('dark');

        readers().forEach((key, read) {
          final token = group[key]! as Map<String, Object?>;
          final expected = parseHex(token[r'$value']! as String);

          expect(
            read(TajeerColors.dark),
            expected,
            reason: 'dark.$key drifted from tokens.json',
          );
        });
      });

      test('the radius scale derives from radius.base', () {
        final json =
            jsonDecode(tokensFile.readAsStringSync()) as Map<String, Object?>;
        final radius =
            (json['radius']! as Map<String, Object?>)['base']!
                as Map<String, Object?>;

        // `0.7rem` at a 16px root.
        final rem = double.parse(
          (radius[r'$value']! as String).replaceAll('rem', ''),
        );

        expect(TajeerRadii.base, rem * 16);
        expect(TajeerRadii.sm, TajeerRadii.base - 4);
        expect(TajeerRadii.md, TajeerRadii.base - 2);
        expect(TajeerRadii.xl, TajeerRadii.base + 4);
      });

      test('the spacing base matches spacing.base', () {
        final json =
            jsonDecode(tokensFile.readAsStringSync()) as Map<String, Object?>;
        final spacing =
            (json['spacing']! as Map<String, Object?>)['base']!
                as Map<String, Object?>;

        final rem = double.parse(
          (spacing[r'$value']! as String).replaceAll('rem', ''),
        );

        expect(TajeerSpacing.base, rem * 16);
      });
    },
    skip: hasTokens
        ? false
        : 'packages/tajeerai-design-system/tokens.json is not reachable '
              'from this checkout.',
  );

  group('palette completeness', () {
    test('light and dark define the same semantic names', () {
      // The whole point of the semantic layer: both appearances remap one set
      // of names, so a component can never ask for a colour that exists in
      // only one theme.
      final light = TajeerColors.light;
      final dark = TajeerColors.dark;

      expect(light.lerp(dark, 0.5), isA<TajeerColors>());
      expect(dark.copyWith(primary: light.primary).primary, light.primary);
    });

    test('the two appearances actually differ', () {
      expect(
        TajeerColors.light.background,
        isNot(TajeerColors.dark.background),
      );
      expect(
        TajeerColors.light.foreground,
        isNot(TajeerColors.dark.foreground),
      );
    });
  });

  group('opaque border derivation', () {
    test('darkens in light mode', () {
      final border = TajeerColors.light.opaqueBorderFor(
        TajeerColors.light.primary,
      );

      // The web computes this by shifting lightness rather than storing a
      // second token per variant.
      expect(
        HSLColor.fromColor(border).lightness,
        lessThan(HSLColor.fromColor(TajeerColors.light.primary).lightness),
      );
    });

    test('lightens in dark mode', () {
      final border = TajeerColors.dark.opaqueBorderFor(
        TajeerColors.dark.primary,
      );

      expect(
        HSLColor.fromColor(border).lightness,
        greaterThan(HSLColor.fromColor(TajeerColors.dark.primary).lightness),
      );
    });

    test('clamps at the extremes rather than wrapping', () {
      expect(
        () => TajeerColors.light.opaqueBorderFor(const Color(0xFF000000)),
        returnsNormally,
      );
      expect(
        () => TajeerColors.dark.opaqueBorderFor(const Color(0xFFFFFFFF)),
        returnsNormally,
      );
    });
  });

  group('ThemeData wiring', () {
    test('both themes carry the palette extension', () {
      expect(AppTheme.light().extension<TajeerColors>(), isNotNull);
      expect(AppTheme.dark().extension<TajeerColors>(), isNotNull);
    });

    test('the scaffold background comes from the token', () {
      expect(
        AppTheme.light().scaffoldBackgroundColor,
        TajeerColors.light.background,
      );
      expect(
        AppTheme.dark().scaffoldBackgroundColor,
        TajeerColors.dark.background,
      );
    });

    test('Material widgets inherit the product palette, not the defaults', () {
      // A stock widget slipping into a screen must not bring Material purple
      // with it.
      expect(AppTheme.light().colorScheme.primary, TajeerColors.light.primary);
      expect(AppTheme.dark().colorScheme.error, TajeerColors.dark.destructive);
    });
  });
}
