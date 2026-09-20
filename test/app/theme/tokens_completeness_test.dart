import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';

import '../../../tool/tokens/token_manifest.dart';

/// What replaced `tokens_parity_test.dart`, and the flaw it designs out.
///
/// The old test walked the *Dart* side: a hand-written map of accessors,
/// compared against `packages/tajeerai-design-system/tokens.json`. It could
/// catch a colour whose value had changed, and it could never catch one that
/// was missing — a token added upstream and never transcribed simply was not
/// in the map, so nothing looked for it. It also read a path a submodule
/// checkout does not have, so CI skipped the whole group while it quietly
/// failed on any developer's machine.
///
/// Every assertion here walks the **token file** instead, and the file is a
/// sibling of `pubspec.yaml`, so there is no `skip:` and no conditional group:
/// it cannot legitimately be absent.
void main() {
  late Map<String, Object?> tokens;

  setUpAll(() {
    tokens = jsonDecode(
      File('design/tokens.json').readAsStringSync(),
    ) as Map<String, Object?>;
  });

  Map<String, Object?> node(Map<String, Object?> from, String key) =>
      from[key]! as Map<String, Object?>;

  Color colorOf(Map<String, Object?> group, String token) {
    final String hex = (node(group, token)[r'$value']! as String).replaceFirst(
      '#',
      '',
    );
    return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
  }

  group('every preset', () {
    test('declares every colour the manifest names, in both themes', () {
      for (final String preset in TokenManifest.presets) {
        final Map<String, Object?> colors = node(
          node(node(tokens, 'preset'), preset),
          'color',
        );
        for (final String theme in TokenManifest.themes) {
          final Map<String, Object?> group = node(colors, theme);
          final Set<String> declared = group.keys
              .where((String key) => !key.startsWith(r'$'))
              .toSet();
          expect(
            declared,
            unorderedEquals(TokenManifest.colors),
            reason:
                '$preset/$theme does not declare exactly the shared token set. '
                'One component set can only render under every preset while '
                'they all answer to the same names.',
          );
        }
      }
    });

    test('reaches Dart with the value the token file gives it', () {
      for (final String preset in TokenManifest.presets) {
        final Map<String, Object?> colors = node(
          node(node(tokens, 'preset'), preset),
          'color',
        );
        for (final String theme in TokenManifest.themes) {
          final TajeerPalette palette = TajeerPalette.of(
            TajeerPreset.fromName(preset),
            theme == 'dark' ? Brightness.dark : Brightness.light,
          );
          final Map<String, Color> dart = palette.colors.asMap;
          final Map<String, Object?> group = node(colors, theme);

          for (final String token in TokenManifest.colors) {
            expect(
              dart[token],
              colorOf(group, token),
              reason: '$preset/$theme/$token drifted from the token file',
            );
          }
        }
      }
    });

    test('resolves to a distinct palette per theme', () {
      for (final String preset in TokenManifest.presets) {
        final TajeerPreset resolved = TajeerPreset.fromName(preset);
        expect(
          TajeerPalette.of(resolved, Brightness.light).colors.background,
          isNot(TajeerPalette.of(resolved, Brightness.dark).colors.background),
          reason: '$preset light and dark share a canvas',
        );
      }
    });

    test('is a distinct identity from every other preset', () {
      final List<Color> accents = <Color>[
        for (final String preset in TokenManifest.presets)
          TajeerPalette.of(
            TajeerPreset.fromName(preset),
            Brightness.light,
          ).colors.primary,
      ];
      expect(accents.toSet(), hasLength(accents.length));
    });
  });

  group('the shared groups', () {
    test('channels are declared once, not per preset', () {
      for (final String theme in TokenManifest.themes) {
        final Map<String, Object?> group = node(node(tokens, 'channel'), theme);
        expect(
          group.keys.where((String key) => !key.startsWith(r'$')).toSet(),
          unorderedEquals(TokenManifest.channels),
        );
      }
      final TajeerChannelColors light = TajeerChannelColors.light;
      for (final String token in TokenManifest.channels) {
        expect(
          light.asMap[token],
          colorOf(node(node(tokens, 'channel'), 'light'), token),
          reason: 'channel/$token drifted',
        );
      }
    });

    test('no channel wears the brand accent of any preset', () {
      // A channel painted in the accent reads as a selected state. This is the
      // rule the token file states; here it is enforced.
      final Set<Color> accents = <Color>{
        for (final String preset in TokenManifest.presets)
          for (final Brightness brightness in Brightness.values)
            TajeerPalette.of(
              TajeerPreset.fromName(preset),
              brightness,
            ).colors.primary,
      };
      for (final MapEntry<String, Color> channel
          in TajeerChannelColors.light.asMap.entries) {
        expect(accents, isNot(contains(channel.value)), reason: channel.key);
      }
      for (final MapEntry<String, Color> channel
          in TajeerChannelColors.dark.asMap.entries) {
        expect(accents, isNot(contains(channel.value)), reason: channel.key);
      }
    });

    test('type, spacing, radii and motion are shared, not per preset', () {
      // A second spacing scale is a second design system. The token file keeps
      // these at the root precisely so a preset cannot acquire one.
      for (final String group in <String>[
        'type',
        'space',
        'radius',
        'motion',
      ]) {
        expect(
          tokens.containsKey(group),
          isTrue,
          reason: '$group is not shared',
        );
      }
      for (final String preset in TokenManifest.presets) {
        final Map<String, Object?> body = node(node(tokens, 'preset'), preset);
        expect(
          body.keys.where((String key) => !key.startsWith(r'$')),
          unorderedEquals(<String>['color', 'elevation']),
          reason:
              '$preset carries something other than a palette and its '
              'elevation. Only colour varies by preset.',
        );
      }
    });

    test('the type scale is the one the token file describes', () {
      final Map<String, Object?> type = node(tokens, 'type');
      final TajeerTypeScale scale = TajeerTypeScale.tajeerLight;
      final Map<String, TextStyle> steps = <String, TextStyle>{
        'display': scale.display,
        'bodyMd': scale.bodyMd,
        'labelSm': scale.labelSm,
        'caption': scale.caption,
      };
      steps.forEach((String name, TextStyle style) {
        final Map<String, Object?> declared =
            node(type, name)[r'$value']! as Map<String, Object?>;
        expect(style.fontSize, (declared['fontSize']! as num).toDouble());
        expect(style.height, (declared['lineHeight']! as num).toDouble());
        expect(style.letterSpacing, 0, reason: '$name must not track Arabic');
      });
    });

    test('every type step uses a weight Tajawal actually ships', () {
      // Tajawal has no 600. Flutter resolves an unavailable weight upward, so a
      // w600 request silently becomes bold and looks entirely plausible.
      final Set<FontWeight> bundled = <FontWeight>{
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w700,
      };
      final TajeerTypeScale scale = TajeerTypeScale.tajeerLight;
      for (final TextStyle style in <TextStyle>[
        scale.display,
        scale.headlineXl,
        scale.headlineLg,
        scale.headlineMd,
        scale.titleLg,
        scale.titleMd,
        scale.titleSm,
        scale.bodyLg,
        scale.bodyMd,
        scale.bodySm,
        scale.labelLg,
        scale.labelMd,
        scale.labelSm,
        scale.caption,
      ]) {
        expect(bundled, contains(style.fontWeight));
      }
    });
  });
}
