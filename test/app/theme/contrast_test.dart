import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';

import '../../../tool/tokens/token_manifest.dart';

/// WCAG 2.1 relative-contrast, over every preset in every theme.
///
/// This runs against the resolved Dart palettes rather than a fixture, so a
/// value edited in `design/tokens.json` is measured on the next run. It is the
/// reason a preset can be added without anybody having to remember to check it:
/// the loop finds it.
///
/// The exemptions below are named and reasoned rather than skipped. A skipped
/// group tells you nothing; an exemption with a stated reason is a decision
/// somebody can disagree with.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Body-text floor. Muted text is held to it too: it carries real prose —
/// timestamps, previews, field descriptions — not decoration.
const double _text = 4.5;

/// Large-text and non-text-contrast floor: a fill, a ring, a boundary.
const double _object = 3;

/// A decorative hairline has to be *visible*, which is a much weaker claim than
/// readable. It is never the only thing identifying a control.
const double _hairline = 1.2;

/// The line *inside* a panel. Quieter than a hairline by design, but still
/// present: below this it has stopped separating anything.
const double _whisper = 1.08;

void main() {
  for (final String presetName in TokenManifest.presets) {
    final TajeerPreset preset = TajeerPreset.fromName(presetName);

    for (final Brightness brightness in Brightness.values) {
      final TajeerPalette palette = TajeerPalette.of(preset, brightness);
      final TajeerColors colors = palette.colors;
      final TajeerElevations elevations = palette.elevations;
      final String label = '$presetName/${brightness.name}';

      /// Everything ink can land on, including the tones elevation introduces —
      /// a dark theme raises a surface by lightening it, and text has to keep
      /// working all the way up the ladder.
      final Map<String, Color> surfaces = <String, Color>{
        'background': colors.background,
        'surface': colors.surface,
        'surfaceMuted': colors.surfaceMuted,
        'surfaceElevated': colors.surfaceElevated,
        'primarySoft': colors.primarySoft,
        for (final String family in TokenManifest.semanticFamilies)
          '${family}Soft': colors.asMap['${family}Soft']!,
        for (final String level in TokenManifest.elevationLevels)
          'elevation.$level': <String, TajeerElevation>{
            'none': elevations.none,
            'subtle': elevations.subtle,
            'card': elevations.card,
            'floating': elevations.floating,
            'popover': elevations.popover,
            'modal': elevations.modal,
          }[level]!.tone,
      };

      group('$label contrast', () {
        test('text is readable on every surface it can land on', () {
          final Map<String, Color> inks = <String, Color>{
            'textPrimary': colors.textPrimary,
            'textSecondary': colors.textSecondary,
            'textMuted': colors.textMuted,
          };
          inks.forEach((String inkName, Color ink) {
            surfaces.forEach((String surfaceName, Color surface) {
              final double ratio = _contrast(ink, surface);
              expect(
                ratio,
                greaterThanOrEqualTo(_text),
                reason:
                    '$label $inkName on $surfaceName is '
                    '${ratio.toStringAsFixed(2)}:1, below $_text:1',
              );
            });
          });
        });

        test('the brand carries its own foreground in every state', () {
          for (final MapEntry<String, Color> state in <String, Color>{
            'primary': colors.primary,
            'primaryHover': colors.primaryHover,
            'primaryPressed': colors.primaryPressed,
          }.entries) {
            final double ratio = _contrast(
              colors.primaryForeground,
              state.value,
            );
            expect(
              ratio,
              greaterThanOrEqualTo(_text),
              reason:
                  '$label primaryForeground on ${state.key} is '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        });

        test('the brand fill has a boundary against the page', () {
          // A yellow fill has no 3:1 edge against white of its own, which is
          // exactly why `primaryBorder` is a token rather than a derivation.
          final double ratio = _contrast(colors.primaryBorder, colors.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(_object),
            reason:
                '$label primaryBorder on surface is ${ratio.toStringAsFixed(2)}:1',
          );
        });

        test('the focus ring is findable', () {
          for (final MapEntry<String, Color> surface in <String, Color>{
            'background': colors.background,
            'surface': colors.surface,
          }.entries) {
            expect(
              _contrast(colors.focus, surface.value),
              greaterThanOrEqualTo(_object),
              reason: '$label focus on ${surface.key}',
            );
          }
        });

        test('each semantic family keeps its four-key contract', () {
          for (final String family in TokenManifest.semanticFamilies) {
            final Color fill = colors.asMap['${family}Default']!;
            final Color soft = colors.asMap['${family}Soft']!;
            final Color ink = colors.asMap['${family}Foreground']!;
            final Color line = colors.asMap['${family}Border']!;

            // `default` is a fill, and `textInverse` is what goes on it.
            expect(
              _contrast(colors.textInverse, fill),
              greaterThanOrEqualTo(_text),
              reason: '$label textInverse on ${family}Default',
            );
            // ...and it must read as an object against the page.
            for (final MapEntry<String, Color> surface in surfaces.entries) {
              expect(
                _contrast(fill, surface.value),
                greaterThanOrEqualTo(_object),
                reason: '$label ${family}Default on ${surface.key}',
              );
            }
            // `foreground` is the ink on `soft`, never on `default`.
            expect(
              _contrast(ink, soft),
              greaterThanOrEqualTo(_text),
              reason: '$label ${family}Foreground on ${family}Soft',
            );
            // `border` only has to be seen.
            expect(
              _contrast(line, soft),
              greaterThanOrEqualTo(_hairline),
              reason: '$label ${family}Border on ${family}Soft',
            );
          }
        });

        test('channel glyphs read as objects, on their wash and the page', () {
          // The named channel colours are shared by every preset, so each one
          // is measured against every preset's own surfaces. A glyph is an
          // object rather than text: 3:1 is its floor.
          final TajeerChannelColors channels = brightness == Brightness.dark
              ? TajeerChannelColors.dark
              : TajeerChannelColors.light;
          for (final String kind in <String>[
            'whatsapp',
            'sms',
            'email',
            'instagram',
            'messenger',
            'liveChat',
          ]) {
            final Color ink = channels.asMap[kind]!;
            final Color wash = channels.asMap['${kind}Soft']!;
            expect(
              _contrast(ink, wash),
              greaterThanOrEqualTo(_object),
              reason: '$label $kind on ${kind}Soft',
            );
            for (final MapEntry<String, Color> surface in <String, Color>{
              'background': colors.background,
              'surface': colors.surface,
              'surfaceMuted': colors.surfaceMuted,
            }.entries) {
              final double ratio = _contrast(ink, surface.value);
              expect(
                ratio,
                greaterThanOrEqualTo(_object),
                reason:
                    '$label $kind on ${surface.key} is '
                    '${ratio.toStringAsFixed(2)}:1',
              );
            }
          }
        });

        test('the hairlines are visible, and ordered', () {
          for (final MapEntry<String, Color> line in <String, Color>{
            'border': colors.border,
            'borderStrong': colors.borderStrong,
          }.entries) {
            expect(
              _contrast(line.value, colors.surface),
              greaterThanOrEqualTo(_hairline),
              reason: '$label ${line.key} on surface',
            );
          }

          // `borderSubtle` sits below even the hairline floor on purpose: it is
          // the line inside a panel, where a full border would cut the panel in
          // two. It has its own, lower floor -- a line nobody can see at all is
          // not a quiet line, it is a missing one.
          expect(
            _contrast(colors.borderSubtle, colors.surface),
            greaterThanOrEqualTo(_whisper),
            reason: '$label borderSubtle has become invisible',
          );

          // The ordering is the real invariant, and the one a well-meaning
          // tweak breaks: subtle < default < strong, or the names are lying.
          final double subtle = _contrast(colors.borderSubtle, colors.surface);
          final double normal = _contrast(colors.border, colors.surface);
          final double strong = _contrast(colors.borderStrong, colors.surface);
          expect(
            subtle,
            lessThan(normal),
            reason: '$label borderSubtle is not subtler than border',
          );
          expect(
            normal,
            lessThan(strong),
            reason: '$label borderStrong is not stronger than border',
          );
        });

        test('named exemptions, so they are decisions and not gaps', () {
          // `textDisabled` sits below the text floor deliberately. WCAG 1.4.3
          // excludes disabled controls, and lifting it would make disabled
          // indistinguishable from enabled — which is the real failure.
          expect(
            _contrast(colors.textDisabled, colors.surface),
            lessThan(_text),
            reason:
                '$label textDisabled now clears the text floor. If that was '
                'deliberate, delete this expectation and say why; if it was '
                'not, disabled controls no longer read as disabled.',
          );
        });
      });
    }
  }
}
