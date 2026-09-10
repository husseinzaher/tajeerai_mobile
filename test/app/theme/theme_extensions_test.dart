import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';

import '../../../tool/tokens/token_manifest.dart';

/// The generated extensions are excluded from the analyzer, so this is the only
/// thing checking them.
///
/// It exists because of what the old suite asserted about `lerp`:
/// `expect(result, isA<TajeerColors>())`, which catches nothing. A `lerp` that
/// forgot a field, or returned `this.primary` where it meant to mix, passes
/// that and produces a colour that is simply wrong halfway through a theme
/// change — visible for 200ms and impossible to screenshot.
void main() {
  group('TajeerColors', () {
    test('lerp lands exactly on each end', () {
      const TajeerColors a = TajeerColors.tajeerLight;
      const TajeerColors b = TajeerColors.tajeerDark;

      final TajeerColors atZero = a.lerp(b, 0);
      final TajeerColors atOne = a.lerp(b, 1);

      for (final String token in TokenManifest.colors) {
        expect(atZero.asMap[token], a.asMap[token], reason: '$token at t=0');
        expect(atOne.asMap[token], b.asMap[token], reason: '$token at t=1');
      }
    });

    test('lerp moves every field, not just the ones somebody remembered', () {
      const TajeerColors a = TajeerColors.tajeerLight;
      const TajeerColors b = TajeerColors.tajeerDark;
      final TajeerColors middle = a.lerp(b, 0.5);

      for (final String token in TokenManifest.colors) {
        final Color from = a.asMap[token]!;
        final Color to = b.asMap[token]!;
        if (from == to) {
          // Some tokens are identical across themes on purpose --
          // `primaryForeground` is, because the yellow does not flip.
          continue;
        }
        expect(
          middle.asMap[token],
          isNot(from),
          reason: '$token did not move at t=0.5, so lerp is dropping it',
        );
      }
    });

    test('lerp against null is the identity', () {
      const TajeerColors a = TajeerColors.tajeerLight;
      expect(a.lerp(null, 0.5).asMap, a.asMap);
    });

    test('copyWith changes what it names and nothing else', () {
      const TajeerColors base = TajeerColors.tajeerLight;
      final TajeerColors changed = base.copyWith(
        primary: const Color(0xFF00FF00),
      );

      expect(changed.primary, const Color(0xFF00FF00));
      for (final String token in TokenManifest.colors) {
        if (token == 'primary') {
          continue;
        }
        expect(changed.asMap[token], base.asMap[token], reason: token);
      }
    });
  });

  group('the other extensions', () {
    test('channel colours lerp and copy', () {
      const TajeerChannelColors a = TajeerChannelColors.light;
      const TajeerChannelColors b = TajeerChannelColors.dark;
      expect(a.lerp(b, 0).asMap, a.asMap);
      expect(a.lerp(b, 1).asMap, b.asMap);
      expect(a.copyWith(whatsapp: const Color(0xFF00FF00)).sms, a.sms);
    });

    test('the type scale lerps its ink without losing a step', () {
      const TajeerTypeScale a = TajeerTypeScale.tajeerLight;
      const TajeerTypeScale b = TajeerTypeScale.tajeerDark;
      expect(a.lerp(b, 0).bodyMd.color, a.bodyMd.color);
      expect(a.lerp(b, 1).bodyMd.color, b.bodyMd.color);
      expect(a.lerp(b, 1).display.fontSize, b.display.fontSize);
      expect(a.lerp(null, 0.5).caption, a.caption);
    });

    test('elevation lerps tone, hairline and shadow together', () {
      const TajeerElevations a = TajeerElevations.tajeerLight;
      const TajeerElevations b = TajeerElevations.tajeerDark;

      expect(a.lerp(b, 0).card.tone, a.card.tone);
      expect(a.lerp(b, 1).card.tone, b.card.tone);
      expect(a.lerp(b, 1).card.hairline, b.card.hairline);
      expect(a.lerp(b, 1).modal.shadow.length, b.modal.shadow.length);
    });

    test('dark elevation climbs by tone, light elevation by shadow', () {
      // The property the {tone, hairline, shadow} triple exists to give: one
      // component expresses depth in both themes without an isDark check.
      for (final String presetName in TokenManifest.presets) {
        final TajeerPreset preset = TajeerPreset.fromName(presetName);
        final TajeerElevations light = TajeerPalette.of(
          preset,
          Brightness.light,
        ).elevations;
        final TajeerElevations dark = TajeerPalette.of(
          preset,
          Brightness.dark,
        ).elevations;

        expect(
          <Color>{light.none.tone, light.card.tone, light.modal.tone},
          hasLength(1),
          reason:
              '$presetName light varies its tone; it should vary its shadow',
        );
        expect(
          <Color>{
            dark.none.tone,
            dark.card.tone,
            dark.floating.tone,
            dark.modal.tone,
          },
          hasLength(greaterThan(2)),
          reason:
              '$presetName dark does not climb by tone. A soft shadow on a '
              'near-black canvas is invisible, so tone is all it has.',
        );
      }
    });
  });

  group('ThemeData', () {
    test('every preset and brightness carries all four extensions', () {
      for (final String presetName in TokenManifest.presets) {
        final TajeerPreset preset = TajeerPreset.fromName(presetName);
        for (final Brightness brightness in Brightness.values) {
          final ThemeData theme = AppTheme.of(preset, brightness);
          expect(
            theme.extension<TajeerColors>(),
            isNotNull,
            reason: presetName,
          );
          expect(theme.extension<TajeerChannelColors>(), isNotNull);
          expect(theme.extension<TajeerTypeScale>(), isNotNull);
          expect(theme.extension<TajeerElevations>(), isNotNull);
          expect(theme.brightness, brightness);
          expect(
            theme.extension<TajeerColors>()!.primary,
            TajeerPalette.of(preset, brightness).colors.primary,
          );
        }
      }
    });

    test('the scaffold and the palette agree on the canvas', () {
      for (final String presetName in TokenManifest.presets) {
        final TajeerPreset preset = TajeerPreset.fromName(presetName);
        for (final Brightness brightness in Brightness.values) {
          final ThemeData theme = AppTheme.of(preset, brightness);
          expect(
            theme.scaffoldBackgroundColor,
            theme.extension<TajeerColors>()!.background,
          );
        }
      }
    });

    test('the bundled typeface actually reaches text', () {
      // Not `ThemeData.fontFamily` -- that is a constructor argument, folded
      // into the text theme. What matters is what a `Text` ends up rendering
      // in, which is this.
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Tajawal');
        expect(
          theme.textTheme.bodyMedium?.fontFamilyFallback,
          contains('Noto Sans Arabic'),
        );
      }
    });
  });

  group('TajeerPreset', () {
    test('an unknown stored name falls back rather than throwing', () {
      // A preference written by a build that knew a preset this one does not
      // must not stop the app opening.
      expect(
        TajeerPreset.fromName('a-preset-from-the-future'),
        TajeerPreset.fallback,
      );
      expect(TajeerPreset.fromName(null), TajeerPreset.fallback);
      expect(TajeerPreset.fromName(''), TajeerPreset.fallback);
    });

    test('every name round-trips', () {
      for (final TajeerPreset preset in TajeerPreset.values) {
        expect(TajeerPreset.fromName(preset.name), preset);
      }
    });

    test('the token file and the enum agree on what exists', () {
      expect(
        TajeerPreset.values.map((TajeerPreset p) => p.name),
        unorderedEquals(TokenManifest.presets),
      );
    });
  });
}
