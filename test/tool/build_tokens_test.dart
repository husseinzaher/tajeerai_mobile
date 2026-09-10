import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/tokens/dart_emitter.dart';
import '../../tool/tokens/token_document.dart';
import '../../tool/tokens/token_format_exception.dart';
import '../../tool/tokens/token_manifest.dart';

/// A complete, valid token tree built from the manifest itself.
///
/// Built rather than written out because the parser demands exactness -- every
/// manifest key present and no others -- so a literal fixture would have to be
/// edited every time a token is added, and the edit nobody makes is the one
/// that turns a real failure into a fixture failure.
Map<String, Object?> minimalDocument() {
  Map<String, Object?> value(Object? v) => <String, Object?>{r'$value': v};

  Map<String, Object?> colorGroup(List<String> tokens, String hex) =>
      <String, Object?>{for (final String token in tokens) token: value(hex)};

  Map<String, Object?> elevationGroup() => <String, Object?>{
    for (final String level in TokenManifest.elevationLevels)
      level: <String, Object?>{
        'tone': value('#FFFFFF'),
        'hairline': value('#EEEEEE'),
        'shadow': value(<Object?>[
          <String, Object?>{
            'color': '#000000',
            'opacity': 0.1,
            'offsetY': 1,
            'blur': 2,
            'spread': 0,
          },
        ]),
      },
  };

  Map<String, Object?> presetBody(String lightHex, String darkHex) =>
      <String, Object?>{
        'color': <String, Object?>{
          'light': colorGroup(TokenManifest.colors, lightHex),
          'dark': colorGroup(TokenManifest.colors, darkHex),
        },
        'elevation': <String, Object?>{
          'light': elevationGroup(),
          'dark': elevationGroup(),
        },
      };

  return <String, Object?>{
    'preset': <String, Object?>{
      for (final String preset in TokenManifest.presets)
        preset: presetBody('#112233', '#445566'),
    },
    'channel': <String, Object?>{
      'light': colorGroup(TokenManifest.channels, '#778899'),
      'dark': colorGroup(TokenManifest.channels, '#AABBCC'),
    },
    'type': <String, Object?>{
      for (final String step in TokenManifest.typeSteps)
        step: value(<String, Object?>{
          'fontSize': 16,
          'lineHeight': 1.5,
          'fontWeight': 400,
          'letterSpacing': 0,
        }),
    },
    'space': <String, Object?>{
      for (final String step in TokenManifest.spaceSteps) step: value('1rem'),
    },
    'radius': <String, Object?>{
      for (final String step in TokenManifest.radiusSteps)
        step: value('0.5rem'),
    },
    'motion': <String, Object?>{
      'durationFast': value('120ms'),
      'durationNormal': value('200ms'),
      'durationSlow': value('320ms'),
      'easingStandard': value('cubic-bezier(0.2, 0, 0, 1)'),
      'easingEmphasized': value('cubic-bezier(0.32, 0.72, 0, 1)'),
      'pressScale': value(0.98),
    },
  };
}

/// Replaces one leaf's `$value`, addressed the way the parser addresses it.
void setValue(
  Map<String, Object?> document,
  String pointer,
  Object? replacement,
) {
  final List<String> segments = pointer.split('.');
  Object? node = document;
  for (final String segment in segments) {
    node = (node! as Map<String, Object?>)[segment];
  }
  (node! as Map<String, Object?>)[r'$value'] = replacement;
}

/// Reaches one preset's group — `preset.<name>.<group>`.
Map<String, Object?> preset(
  Map<String, Object?> document,
  String name,
  String group,
) =>
    ((document['preset']! as Map<String, Object?>)[name]!
            as Map<String, Object?>)[group]!
        as Map<String, Object?>;

TokenFormatException failureFor(Map<String, Object?> document) {
  try {
    TokenDocument.parse(document);
  } on TokenFormatException catch (error) {
    return error;
  }
  fail('expected the document to be rejected, but it parsed');
}

void main() {
  group('the real token file', () {
    late TokenDocument document;

    setUp(() {
      final Object? decoded = jsonDecode(
        File('design/tokens.json').readAsStringSync(),
      );
      document = TokenDocument.parse(decoded! as Map<String, Object?>);
    });

    test('parses, and carries every token the manifest names', () {
      // Every preset answers to the same names. That is the property that lets
      // one component set render under all of them.
      for (final String preset in TokenManifest.presets) {
        for (final String theme in TokenManifest.themes) {
          expect(
            document.colors[preset]![theme]!.keys,
            unorderedEquals(TokenManifest.colors),
            reason: '$preset/$theme',
          );
          expect(
            document.elevation[preset]![theme]!.keys,
            unorderedEquals(TokenManifest.elevationLevels),
            reason: '$preset/$theme',
          );
        }
      }
      for (final String theme in TokenManifest.themes) {
        expect(
          document.channels[theme]!.keys,
          unorderedEquals(TokenManifest.channels),
        );
      }
      expect(document.type.keys, unorderedEquals(TokenManifest.typeSteps));
      expect(document.space.keys, unorderedEquals(TokenManifest.spaceSteps));
      expect(document.radius.keys, unorderedEquals(TokenManifest.radiusSteps));
    });

    test('emits source that dart format leaves alone', () {
      // CI runs `dart format --set-exit-if-changed` over lib/, and does not
      // exclude generated sources. A generator whose output the formatter
      // rewrites fails the build in a way that looks nothing like a token
      // problem, so the emitter and the formatter must already agree.
      final String emitted = DartEmitter.emit(document);
      final DartFormatter formatter = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      );
      final String formatted = formatter.format(emitted);
      expect(formatter.format(formatted), formatted);
    });

    test('resolves aliases rather than emitting them', () {
      // Every preset's card hairline is an alias to that preset's own border.
      for (final String preset in TokenManifest.presets) {
        expect(
          document.elevation[preset]!['light']!['card']!.hairline,
          document.colors[preset]!['light']!['border'],
          reason: preset,
        );
      }
      expect(DartEmitter.emit(document), isNot(contains('{preset.')));
    });

    test('emits a field for every token, and a palette per preset', () {
      final String source = DartEmitter.emit(document);
      for (final String token in TokenManifest.colors) {
        expect(
          source,
          contains('final Color ${TokenManifest.identifier(token)};'),
          reason: '$token has no field on TajeerColors',
        );
      }
      for (final String step in TokenManifest.typeSteps) {
        expect(source, contains('final TextStyle $step;'));
      }
      // One palette variant per preset per theme, and an enum value per preset.
      for (final String preset in TokenManifest.presets) {
        expect(source, contains('TajeerPreset.$preset:'));
        for (final String theme in TokenManifest.themes) {
          expect(
            source,
            contains(
              'static const TajeerColors ${DartEmitter.variant(preset, theme)}',
            ),
          );
        }
      }
    });
  });

  group('rejection', () {
    test('an unknown token, rather than silently dropping it', () {
      // The regression test for the flaw in the palette this replaced: its
      // check iterated the Dart side, so a token added to the token file and
      // never transcribed was invisible to it.
      final Map<String, Object?> document = minimalDocument();
      final Map<String, Object?> colors = preset(document, 'tajeer', 'color');
      colors['light'] = <String, Object?>{
        ...colors['light']! as Map<String, Object?>,
        'brandTertiary': <String, Object?>{r'$value': '#123456'},
      };

      final TokenFormatException failure = failureFor(document);
      expect(failure.pointer, 'preset.tajeer.color.light');
      expect(failure.message, contains('brandTertiary'));
      expect(failure.message, contains('TokenManifest'));
    });

    test('a token missing from one theme only', () {
      final Map<String, Object?> document = minimalDocument();
      (preset(document, 'aurora', 'color')['dark']! as Map<String, Object?>)
          .remove('focus');

      final TokenFormatException failure = failureFor(document);
      expect(failure.pointer, 'preset.aurora.color.dark');
      expect(failure.message, contains('focus'));
    });

    test('a malformed colour, naming the node', () {
      final Map<String, Object?> document = minimalDocument();
      setValue(document, 'preset.tajeer.color.dark.primary', 'rgb(1, 2, 3)');

      final TokenFormatException failure = failureFor(document);
      expect(failure.pointer, 'preset.tajeer.color.dark.primary');
      expect(failure.message, contains('#RRGGBB'));
    });

    test('an alias that resolves to nothing', () {
      final Map<String, Object?> document = minimalDocument();
      setValue(
        document,
        'preset.tajeer.color.light.border',
        '{preset.tajeer.color.light.doesNotExist}',
      );

      expect(failureFor(document).message, contains('no such node'));
    });

    test('an alias that resolves in a circle', () {
      final Map<String, Object?> document = minimalDocument();
      setValue(
        document,
        'preset.tajeer.color.light.border',
        '{preset.tajeer.color.light.borderStrong}',
      );
      setValue(
        document,
        'preset.tajeer.color.light.borderStrong',
        '{preset.tajeer.color.light.border}',
      );

      expect(failureFor(document).message, contains('alias cycle'));
    });

    test('a type step missing a sub-key', () {
      final Map<String, Object?> document = minimalDocument();
      setValue(document, 'type.bodyMd', <String, Object?>{
        'fontSize': 15,
        'lineHeight': 1.7,
        'fontWeight': 400,
      });

      final TokenFormatException failure = failureFor(document);
      expect(failure.pointer, 'type.bodyMd');
      expect(failure.message, contains('letterSpacing'));
    });

    test('a font weight Tajawal cannot honour', () {
      // Tajawal ships no 600. A w600 request resolves upward to 700 and looks
      // entirely fine, which is why it has to fail here instead.
      final Map<String, Object?> document = minimalDocument();
      setValue(document, 'type.titleMd', <String, Object?>{
        'fontSize': 16,
        'lineHeight': 1.55,
        'fontWeight': 640,
        'letterSpacing': 0,
      });

      expect(failureFor(document).message, contains('hundred-step weight'));
    });

    test('a dimension with no unit the client understands', () {
      final Map<String, Object?> document = minimalDocument();
      setValue(document, 'space.md', '16pt');

      expect(failureFor(document).message, contains('rem or px'));
    });
  });

  group('value conversion', () {
    late TokenDocument document;

    setUp(() => document = TokenDocument.parse(minimalDocument()));

    test('rem resolves against a 16px root', () {
      expect(document.space['md'], 16);
      expect(document.radius['sm'], 8);
    });

    test('a six-digit colour gains an opaque alpha, alpha-first', () {
      expect(document.colors['tajeer']!['light']!['primary'], '#FF112233');
    });

    test(
      'an eight-digit colour is read as Dart writes it, not as CSS does',
      () {
        final Map<String, Object?> raw = minimalDocument();
        setValue(raw, 'preset.tajeer.color.light.surfaceOverlay', '#99112233');

        expect(
          TokenDocument.parse(raw)
              .colors['tajeer']!['light']!['surfaceOverlay'],
          '#99112233',
        );
      },
    );

    test('shadow opacity folds into the emitted colour', () {
      // 0.1 * 255 = 25.5, rounded to 26 = 0x1A.
      expect(DartEmitter.emit(document), contains('Color(0x1A000000)'));
    });

    test('a whole number emits as a double literal', () {
      // `fontSize: 16` in a const TextStyle must be `16.0` in Dart.
      expect(DartEmitter.emit(document), contains('fontSize: 16.0'));
    });
  });

  group('identifier mangling', () {
    test('moves leading digits to the end, and leaves the rest alone', () {
      expect(TokenManifest.identifier('2xs'), 'xs2');
      expect(TokenManifest.identifier('4xl'), 'xl4');
      expect(TokenManifest.identifier('md'), 'md');
      expect(
        TokenManifest.identifier('primaryForeground'),
        'primaryForeground',
      );
    });

    test('produces a legal Dart identifier for every step in the manifest', () {
      final RegExp legal = RegExp(r'^[a-z][A-Za-z0-9]*$');
      for (final String step in <String>[
        ...TokenManifest.spaceSteps,
        ...TokenManifest.radiusSteps,
        ...TokenManifest.colors,
        ...TokenManifest.channels,
        ...TokenManifest.typeSteps,
        ...TokenManifest.elevationLevels,
      ]) {
        expect(TokenManifest.identifier(step), matches(legal), reason: step);
      }
    });
  });
}
