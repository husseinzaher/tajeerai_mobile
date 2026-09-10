import 'token_document.dart';
import 'token_manifest.dart';

/// Turns a [TokenDocument] into the source of `lib/app/theme/tokens.g.dart`.
///
/// A pure `TokenDocument -> String` function, deliberately: unlike the web's
/// Node generator this one runs in the language it emits, so a test can call
/// [emit] on a hand-built document with no filesystem and no subprocess.
///
/// It emits the `ThemeExtension` classes whole, `copyWith` and `lerp` included,
/// rather than a map of colours a hand-written extension reads. Two reasons.
/// A map costs the compile-time safety that makes `context.colors.primary`
/// unmistakable, and `lerp` cannot be written over one at all. And a
/// hand-maintained `copyWith` across ~38 fields is 38 lines that can only ever
/// be wrong, failing silently: `primary: primary ?? this.primaryHover`
/// compiles, ships, and is found by a designer.
abstract final class DartEmitter {
  static String emit(TokenDocument document) {
    final StringBuffer out = StringBuffer();

    out.writeln('''
// GENERATED FROM design/tokens.json BY tool/build_tokens.dart -- DO NOT EDIT.
//
// Run `make tokens` after changing the token file. Editing this file by hand is
// undone by the next generation, and `dart run tool/build_tokens.dart --check`
// will tell you so.
//
// Type styles carry size, height, weight, spacing and ink, but NOT a font
// family: the family is applied once by `AppTheme` so a single change of face
// reaches every style. A style used inside the app therefore merges over the
// ambient text theme, which is what supplies Tajawal and its fallbacks.

import 'package:flutter/material.dart';
''');

    _emitColors(out, document);
    _emitChannelColors(out, document);
    _emitTypeScale(out, document);
    _emitElevations(out, document);
    _emitPalette(out);
    _emitSpacing(out, document);
    _emitRadii(out, document);
    _emitMotion(out, document);

    return out.toString();
  }

  // -- colours --------------------------------------------------------------

  static void _emitColors(StringBuffer out, TokenDocument document) {
    _emitColorExtension(
      out,
      className: 'TajeerColors',
      accessor: 'colors',
      tokens: TokenManifest.colors,
      values: <String, Map<String, String>>{
        for (final String preset in TokenManifest.presets)
          for (final String theme in TokenManifest.themes)
            variant(preset, theme): document.colors[preset]![theme]!,
      },
      docs: '''
/// The semantic palette, in both appearances.
///
/// A widget asks for [TajeerColors.primary], never for a hex, so it cannot be
/// right in one theme and wrong in the other. Reached as `context.colors`.
///
/// Every value, and the reason behind it, lives in `design/tokens.json`.''',
    );
  }

  static void _emitChannelColors(StringBuffer out, TokenDocument document) {
    _emitColorExtension(
      out,
      className: 'TajeerChannelColors',
      accessor: 'channels',
      tokens: TokenManifest.channels,
      values: <String, Map<String, String>>{
        for (final String theme in TokenManifest.themes)
          theme: document.channels[theme]!,
      },
      docs: '''
/// The six named communication channels, as ink and wash per theme.
///
/// Separate from [TajeerColors] on purpose. Its membership tracks a *product*
/// decision -- adding Telegram -- rather than a design one, so it churns on a
/// different clock; nothing outside the conversations UI reads it, and folding
/// it in would put twelve irrelevant entries in every `context.colors.`
/// completion. Reached as `context.channels`.''',
    );
  }

  static void _emitColorExtension(
    StringBuffer out, {
    required String className,
    required String accessor,
    required List<String> tokens,
    required Map<String, Map<String, String>> values,
    required String docs,
  }) {
    out
      ..writeln(docs)
      ..writeln('@immutable')
      ..writeln('class $className extends ThemeExtension<$className> {')
      ..writeln('const $className({');
    for (final String token in tokens) {
      out.writeln('required this.${TokenManifest.identifier(token)},');
    }
    out.writeln('});');

    for (final MapEntry<String, Map<String, String>> entry in values.entries) {
      out
        ..writeln()
        ..writeln('static const $className ${entry.key} = $className(');
      for (final String token in tokens) {
        out.writeln(
          '${TokenManifest.identifier(token)}: ${_color(entry.value[token]!)},',
        );
      }
      out.writeln(');');
    }

    out.writeln();
    for (final String token in tokens) {
      out.writeln('final Color ${TokenManifest.identifier(token)};');
    }

    // copyWith
    out
      ..writeln()
      ..writeln('@override')
      ..writeln('$className copyWith({');
    for (final String token in tokens) {
      out.writeln('Color? ${TokenManifest.identifier(token)},');
    }
    out
      ..writeln('}) {')
      ..writeln('return $className(');
    for (final String token in tokens) {
      final String field = TokenManifest.identifier(token);
      out.writeln('$field: $field ?? this.$field,');
    }
    out
      ..writeln(');')
      ..writeln('}');

    // asMap
    out
      ..writeln()
      ..writeln('/// Every token by its name in `design/tokens.json`.')
      ..writeln('///')
      ..writeln(
        '/// Generated, so it cannot drift from the fields above. It is what',
      )
      ..writeln(
        '/// lets a test walk the token file and check the Dart against it',
      )
      ..writeln(
        '/// without a hand-written index of accessors -- an index that could',
      )
      ..writeln(
        '/// only ever be missing the token nobody transcribed. The showcase',
      )
      ..writeln('/// draws its palette grid from the same map.')
      ..writeln('Map<String, Color> get asMap => <String, Color>{');
    for (final String token in tokens) {
      out.writeln("'$token': ${TokenManifest.identifier(token)},");
    }
    out.writeln('};');

    // lerp
    out
      ..writeln()
      ..writeln('@override')
      ..writeln('$className lerp($className? other, double t) {')
      ..writeln('if (other == null) {')
      ..writeln('return this;')
      ..writeln('}')
      ..writeln('Color mix(Color a, Color b) => Color.lerp(a, b, t)!;')
      ..writeln('return $className(');
    for (final String token in tokens) {
      final String field = TokenManifest.identifier(token);
      out.writeln('$field: mix($field, other.$field),');
    }
    out
      ..writeln(');')
      ..writeln('}')
      ..writeln('}')
      ..writeln();
  }

  // -- type -----------------------------------------------------------------

  static void _emitTypeScale(StringBuffer out, TokenDocument document) {
    out
      ..writeln('''
/// The fourteen-step type scale, with its ink already applied.
///
/// `Text(x, style: context.type.bodyMd)` is therefore correct with no
/// `copyWith`, and -- because this is a `ThemeExtension` -- the colour animates
/// across a theme change along with everything else.
///
/// `leadingDistribution` is `even` on every step. Flutter's default puts most
/// of the extra leading below the baseline, and at the generous heights Arabic
/// wants, that makes a single-line label sit visibly high in its button.''')
      ..writeln('@immutable')
      ..writeln(
        'class TajeerTypeScale extends ThemeExtension<TajeerTypeScale> {',
      )
      ..writeln('const TajeerTypeScale({');
    for (final String step in TokenManifest.typeSteps) {
      out.writeln('required this.$step,');
    }
    out.writeln('});');

    for (final String preset in TokenManifest.presets) {
      for (final String theme in TokenManifest.themes) {
        final String ink = document.colors[preset]![theme]!['textPrimary']!;
        out
          ..writeln()
          ..writeln(
            'static const TajeerTypeScale ${variant(preset, theme)} = TajeerTypeScale(',
          );
        for (final String step in TokenManifest.typeSteps) {
          out.writeln('$step: ${_textStyle(document.type[step]!, ink)},');
        }
        out.writeln(');');
      }
    }

    out.writeln();
    for (final String step in TokenManifest.typeSteps) {
      out.writeln('final TextStyle $step;');
    }

    out
      ..writeln()
      ..writeln('@override')
      ..writeln('TajeerTypeScale copyWith({');
    for (final String step in TokenManifest.typeSteps) {
      out.writeln('TextStyle? $step,');
    }
    out
      ..writeln('}) {')
      ..writeln('return TajeerTypeScale(');
    for (final String step in TokenManifest.typeSteps) {
      out.writeln('$step: $step ?? this.$step,');
    }
    out
      ..writeln(');')
      ..writeln('}');

    out
      ..writeln()
      ..writeln('@override')
      ..writeln('TajeerTypeScale lerp(TajeerTypeScale? other, double t) {')
      ..writeln('if (other == null) {')
      ..writeln('return this;')
      ..writeln('}')
      ..writeln('return TajeerTypeScale(');
    for (final String step in TokenManifest.typeSteps) {
      out.writeln('$step: TextStyle.lerp($step, other.$step, t)!,');
    }
    out
      ..writeln(');')
      ..writeln('}')
      ..writeln('}')
      ..writeln();
  }

  static String _textStyle(TypeStep step, String ink) {
    return 'TextStyle('
        'fontSize: ${_double(step.fontSize)}, '
        'height: ${_double(step.lineHeight)}, '
        'fontWeight: FontWeight.w${step.fontWeight}, '
        'letterSpacing: ${_double(step.letterSpacing)}, '
        'leadingDistribution: TextLeadingDistribution.even, '
        'color: ${_color(ink)},'
        ')';
  }

  // -- elevation ------------------------------------------------------------

  static void _emitElevations(StringBuffer out, TokenDocument document) {
    out.writeln('''
/// One depth level: the surface it paints, the line around it, and what it
/// casts.
///
/// All three together, because the two themes express depth differently -- in
/// light the tone holds at white and the shadow carries the level, in dark the
/// shadow is nearly constant and the tone and hairline carry it. A component
/// reads all three and is correct in both without asking which it is in.
@immutable
class TajeerElevation {
  const TajeerElevation({
    required this.tone,
    required this.hairline,
    required this.shadow,
  });

  final Color tone;
  final Color hairline;
  final List<BoxShadow> shadow;

  static TajeerElevation lerp(TajeerElevation a, TajeerElevation b, double t) {
    return TajeerElevation(
      tone: Color.lerp(a.tone, b.tone, t)!,
      hairline: Color.lerp(a.hairline, b.hairline, t)!,
      shadow: BoxShadow.lerpList(a.shadow, b.shadow, t) ?? b.shadow,
    );
  }
}
''');

    out
      ..writeln(
        '/// The six depth levels, in both appearances. `context.elevation`.',
      )
      ..writeln('@immutable')
      ..writeln(
        'class TajeerElevations extends ThemeExtension<TajeerElevations> {',
      )
      ..writeln('const TajeerElevations({');
    for (final String level in TokenManifest.elevationLevels) {
      out.writeln('required this.$level,');
    }
    out.writeln('});');

    for (final String preset in TokenManifest.presets) {
      for (final String theme in TokenManifest.themes) {
        out
          ..writeln()
          ..writeln(
            'static const TajeerElevations ${variant(preset, theme)} = TajeerElevations(',
          );
        for (final String level in TokenManifest.elevationLevels) {
          out.writeln(
            '$level: ${_elevation(document.elevation[preset]![theme]![level]!)},',
          );
        }
        out.writeln(');');
      }
    }

    out.writeln();
    for (final String level in TokenManifest.elevationLevels) {
      out.writeln('final TajeerElevation $level;');
    }

    out
      ..writeln()
      ..writeln('@override')
      ..writeln('TajeerElevations copyWith({');
    for (final String level in TokenManifest.elevationLevels) {
      out.writeln('TajeerElevation? $level,');
    }
    out
      ..writeln('}) {')
      ..writeln('return TajeerElevations(');
    for (final String level in TokenManifest.elevationLevels) {
      out.writeln('$level: $level ?? this.$level,');
    }
    out
      ..writeln(');')
      ..writeln('}');

    out
      ..writeln()
      ..writeln('@override')
      ..writeln('TajeerElevations lerp(TajeerElevations? other, double t) {')
      ..writeln('if (other == null) {')
      ..writeln('return this;')
      ..writeln('}')
      ..writeln('return TajeerElevations(');
    for (final String level in TokenManifest.elevationLevels) {
      out.writeln('$level: TajeerElevation.lerp($level, other.$level, t),');
    }
    out
      ..writeln(');')
      ..writeln('}')
      ..writeln('}')
      ..writeln();
  }

  static String _elevation(ElevationLevel level) {
    final StringBuffer shadows = StringBuffer('<BoxShadow>[');
    for (final ShadowSpec shadow in level.shadow) {
      shadows.write(
        'BoxShadow('
        'color: ${_colorWithOpacity(shadow.color, shadow.opacity)}, '
        'offset: Offset(0, ${_double(shadow.offsetY)}), '
        'blurRadius: ${_double(shadow.blur)}, '
        'spreadRadius: ${_double(shadow.spread)},'
        '),',
      );
    }
    shadows.write(']');

    return 'TajeerElevation('
        'tone: ${_color(level.tone)}, '
        'hairline: ${_color(level.hairline)}, '
        'shadow: $shadows,'
        ')';
  }

  /// The preset enum and the lookup that resolves (preset, brightness) to the
  /// three extensions that vary with it.
  ///
  /// Generated rather than hand-written so that adding a preset to the token
  /// file adds it here too. A hand-written switch would compile perfectly well
  /// while missing the new preset, and the first anyone would know is a screen
  /// rendered in the wrong palette.
  static void _emitPalette(StringBuffer out) {
    out
      ..writeln('/// The visual presets this build carries.')
      ..writeln('enum TajeerPreset {');
    for (final String preset in TokenManifest.presets) {
      out.writeln('$preset,');
    }
    out
      ..writeln(';')
      ..writeln()
      ..writeln('/// What a fresh install wears, and the fallback for a stored')
      ..writeln('/// value nobody recognises any more.')
      ..writeln(
        'static const TajeerPreset fallback = TajeerPreset.${TokenManifest.defaultPreset};',
      )
      ..writeln()
      ..writeln(
        '/// Resolves a persisted name, falling back rather than throwing:',
      )
      ..writeln(
        '/// a preference written by a build that knew a preset this one',
      )
      ..writeln('/// does not must not stop the app opening.')
      ..writeln(
        'static TajeerPreset fromName(String? name) => TajeerPreset.values',
      )
      ..writeln(
        '.firstWhere((TajeerPreset p) => p.name == name, orElse: () => fallback);',
      )
      ..writeln('}')
      ..writeln()
      ..writeln('/// Everything a preset decides, for one brightness.')
      ..writeln('@immutable')
      ..writeln('class TajeerPalette {')
      ..writeln('const TajeerPalette({')
      ..writeln('required this.colors,')
      ..writeln('required this.elevations,')
      ..writeln('required this.type,')
      ..writeln('});')
      ..writeln()
      ..writeln('final TajeerColors colors;')
      ..writeln('final TajeerElevations elevations;')
      ..writeln('final TajeerTypeScale type;')
      ..writeln()
      ..writeln(
        'static const Map<TajeerPreset, Map<Brightness, TajeerPalette>> all =',
      )
      ..writeln('<TajeerPreset, Map<Brightness, TajeerPalette>>{');
    for (final String preset in TokenManifest.presets) {
      out.writeln('TajeerPreset.$preset: <Brightness, TajeerPalette>{');
      for (final String theme in TokenManifest.themes) {
        final String name = variant(preset, theme);
        out
          ..writeln('Brightness.$theme: TajeerPalette(')
          ..writeln('colors: TajeerColors.$name,')
          ..writeln('elevations: TajeerElevations.$name,')
          ..writeln('type: TajeerTypeScale.$name,')
          ..writeln('),');
      }
      out.writeln('},');
    }
    out
      ..writeln('};')
      ..writeln()
      ..writeln(
        'static TajeerPalette of(TajeerPreset preset, Brightness brightness) =>',
      )
      ..writeln('all[preset]![brightness]!;')
      ..writeln('}')
      ..writeln();
  }

  // -- scalars --------------------------------------------------------------

  static void _emitSpacing(StringBuffer out, TokenDocument document) {
    out
      ..writeln('''
/// The spacing scale, in logical pixels.
///
/// Named by size rather than by multiple: a component asks for the step it
/// means instead of counting base units, which is what stops `x2_5` appearing
/// beside `x3` for no reason anybody can reconstruct later.''')
      ..writeln('abstract final class TajeerSpacing {');
    for (final String step in TokenManifest.spaceSteps) {
      out.writeln(
        'static const double ${TokenManifest.identifier(step)} = '
        '${_double(document.space[step]!)};',
      );
    }
    out
      ..writeln('}')
      ..writeln();
  }

  static void _emitRadii(StringBuffer out, TokenDocument document) {
    out
      ..writeln('''
/// Corner radii, and their prebuilt `BorderRadius` companions.
///
/// Round numbers with no derivation: the scale these replaced computed every
/// step from one base and produced 7.2, 9.2, 11.2 and 15.2 -- values nobody
/// chose, tracking a web variable this client no longer shares.''')
      ..writeln('abstract final class TajeerRadii {');
    for (final String step in TokenManifest.radiusSteps) {
      out.writeln(
        'static const double ${TokenManifest.identifier(step)} = '
        '${_double(document.radius[step]!)};',
      );
    }
    out.writeln();
    for (final String step in TokenManifest.radiusSteps) {
      final String name = TokenManifest.identifier(step);
      out.writeln(
        'static const BorderRadius ${name}All = '
        'BorderRadius.all(Radius.circular($name));',
      );
    }
    out
      ..writeln('}')
      ..writeln();
  }

  static void _emitMotion(StringBuffer out, TokenDocument document) {
    final MotionTokens motion = document.motion;
    out
      ..writeln('''
/// Raw motion values.
///
/// Components do not read these -- they read `context.motion`, which returns a
/// zeroed set when the platform asks for reduced motion. That way no component
/// checks a flag, exactly as none of them checks whether the theme is dark.''')
      ..writeln('abstract final class TajeerMotionTokens {')
      ..writeln(
        'static const Duration durationFast = Duration(milliseconds: ${motion.fastMs});',
      )
      ..writeln(
        'static const Duration durationNormal = Duration(milliseconds: ${motion.normalMs});',
      )
      ..writeln(
        'static const Duration durationSlow = Duration(milliseconds: ${motion.slowMs});',
      )
      ..writeln()
      ..writeln(
        'static const Curve easingStandard = ${_curve(motion.standard)};',
      )
      ..writeln(
        'static const Curve easingEmphasized = ${_curve(motion.emphasized)};',
      )
      ..writeln()
      ..writeln(
        'static const double pressScale = ${_double(motion.pressScale)};',
      )
      ..writeln('}');
  }

  static String _curve(List<double> points) {
    final String args = points.map(_double).join(', ');
    return 'Cubic($args)';
  }

  /// The name of one palette variant: `aurora` + `light` -> `auroraLight`.
  static String variant(String preset, String theme) =>
      '$preset${theme[0].toUpperCase()}${theme.substring(1)}';

  // -- literals -------------------------------------------------------------

  static String _color(String hex) => 'Color(0x${hex.substring(1)})';

  /// A shadow's ink and its strength are authored apart so one ink can be
  /// reused at several strengths; they are folded together here.
  static String _colorWithOpacity(String hex, double opacity) {
    final int alpha = (opacity * 255).round().clamp(0, 255);
    final String channels = hex.substring(3);
    return 'Color(0x${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}$channels)';
  }

  /// Dart needs `4.0`, not `4`, for a `double` literal in a const expression.
  static String _double(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return '${value.toInt()}.0';
    }
    return value.toString();
  }
}
