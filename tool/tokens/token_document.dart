import 'token_format_exception.dart';
import 'token_manifest.dart';

/// One step of the type scale.
class TypeStep {
  const TypeStep({
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.letterSpacing,
  });

  final double fontSize;

  /// A unitless multiplier, mapping straight onto Flutter's `TextStyle.height`.
  final double lineHeight;

  final int fontWeight;
  final double letterSpacing;
}

/// One shadow, authored as Flutter means it rather than as CSS spells it.
class ShadowSpec {
  const ShadowSpec({
    required this.color,
    required this.opacity,
    required this.offsetY,
    required this.blur,
    required this.spread,
  });

  /// `#RRGGBB`, with [opacity] applied separately so the same ink can be reused
  /// at several strengths without repeating a hex.
  final String color;
  final double opacity;
  final double offsetY;
  final double blur;
  final double spread;
}

/// A depth level: the surface it paints, the line around it, and what it casts.
///
/// All three, because light expresses depth as a shadow and dark expresses it as
/// a tone step plus a hairline. Carrying the triple is what lets one component
/// render correctly in both without asking which theme it is in.
class ElevationLevel {
  const ElevationLevel({
    required this.tone,
    required this.hairline,
    required this.shadow,
  });

  final String tone;
  final String hairline;
  final List<ShadowSpec> shadow;
}

class MotionTokens {
  const MotionTokens({
    required this.fastMs,
    required this.normalMs,
    required this.slowMs,
    required this.standard,
    required this.emphasized,
    required this.pressScale,
  });

  final int fastMs;
  final int normalMs;
  final int slowMs;

  /// The four control points of a cubic bezier.
  final List<double> standard;
  final List<double> emphasized;

  final double pressScale;
}

/// `design/tokens.json`, parsed and validated.
///
/// Parsing fails rather than emits. A generator that skips what it does not
/// understand produces a Dart file that compiles and is quietly missing a
/// colour, which is the failure mode this whole pipeline exists to remove.
class TokenDocument {
  const TokenDocument({
    required this.colors,
    required this.channels,
    required this.type,
    required this.space,
    required this.radius,
    required this.elevation,
    required this.motion,
  });

  /// preset -> theme -> token -> `#AARRGGBB`.
  final Map<String, Map<String, Map<String, String>>> colors;

  /// theme -> channel token -> `#AARRGGBB`.
  final Map<String, Map<String, String>> channels;

  final Map<String, TypeStep> type;

  /// Step -> logical pixels.
  final Map<String, double> space;
  final Map<String, double> radius;

  /// preset -> theme -> level -> value.
  final Map<String, Map<String, Map<String, ElevationLevel>>> elevation;

  final MotionTokens motion;

  static final RegExp _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
  static final RegExp _alias = RegExp(r'^\{([A-Za-z0-9_.]+)\}$');
  static final RegExp _dimension = RegExp(r'^(-?[0-9]*\.?[0-9]+)(rem|px)$');
  static final RegExp _duration = RegExp(r'^([0-9]+)ms$');
  static final RegExp _bezier = RegExp(
    r'^cubic-bezier\(\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\)$',
  );

  /// The rem root. The token file authors spacing and radii in rem to match the
  /// web file's convention; Flutter has no such unit, so it is resolved here.
  static const double remRoot = 16;

  static TokenDocument parse(Map<String, Object?> root) {
    final Map<String, Map<String, Map<String, String>>> colors =
        <String, Map<String, Map<String, String>>>{};
    final Map<String, Map<String, Map<String, ElevationLevel>>> elevation =
        <String, Map<String, Map<String, ElevationLevel>>>{};
    final Map<String, Map<String, String>> channels =
        <String, Map<String, String>>{};

    _requireExactKeys('preset', _group(root, 'preset'), TokenManifest.presets);

    for (final String preset in TokenManifest.presets) {
      final Map<String, Map<String, String>> presetColors =
          <String, Map<String, String>>{};
      final Map<String, Map<String, ElevationLevel>> presetElevation =
          <String, Map<String, ElevationLevel>>{};

      for (final String theme in TokenManifest.themes) {
        presetColors[theme] = _readColorGroup(
          root,
          'preset.$preset.color.$theme',
          TokenManifest.colors,
        );
        presetElevation[theme] = _readElevationGroup(
          root,
          'preset.$preset.elevation.$theme',
        );
      }

      _requireSymmetry('preset.$preset.color', presetColors);
      colors[preset] = presetColors;
      elevation[preset] = presetElevation;
    }

    for (final String theme in TokenManifest.themes) {
      channels[theme] = _readColorGroup(
        root,
        'channel.$theme',
        TokenManifest.channels,
      );
    }
    _requireSymmetry('channel', channels);

    return TokenDocument(
      colors: colors,
      channels: channels,
      type: _readTypeGroup(root),
      space: _readDimensionGroup(root, 'space', TokenManifest.spaceSteps),
      radius: _readDimensionGroup(root, 'radius', TokenManifest.radiusSteps),
      elevation: elevation,
      motion: _readMotion(root),
    );
  }

  // -- groups ---------------------------------------------------------------

  static Map<String, String> _readColorGroup(
    Map<String, Object?> root,
    String pointer,
    List<String> expected,
  ) {
    final Map<String, Object?> group = _group(root, pointer);
    _requireExactKeys(pointer, group, expected);

    return <String, String>{
      for (final String name in expected)
        name: _color('$pointer.$name', _value(root, '$pointer.$name')),
    };
  }

  static Map<String, TypeStep> _readTypeGroup(Map<String, Object?> root) {
    final Map<String, Object?> group = _group(root, 'type');
    _requireExactKeys('type', group, TokenManifest.typeSteps);

    return <String, TypeStep>{
      for (final String step in TokenManifest.typeSteps)
        step: _typeStep('type.$step', _value(root, 'type.$step')),
    };
  }

  static Map<String, double> _readDimensionGroup(
    Map<String, Object?> root,
    String pointer,
    List<String> expected,
  ) {
    final Map<String, Object?> group = _group(root, pointer);
    _requireExactKeys(pointer, group, expected);

    return <String, double>{
      for (final String step in expected)
        step: _dimensionValue('$pointer.$step', _value(root, '$pointer.$step')),
    };
  }

  static Map<String, ElevationLevel> _readElevationGroup(
    Map<String, Object?> root,
    String pointer,
  ) {
    final Map<String, Object?> group = _group(root, pointer);
    _requireExactKeys(pointer, group, TokenManifest.elevationLevels);

    return <String, ElevationLevel>{
      for (final String level in TokenManifest.elevationLevels)
        level: ElevationLevel(
          tone: _color(
            '$pointer.$level.tone',
            _value(root, '$pointer.$level.tone'),
          ),
          hairline: _color(
            '$pointer.$level.hairline',
            _value(root, '$pointer.$level.hairline'),
          ),
          shadow: _shadows(
            '$pointer.$level.shadow',
            _value(root, '$pointer.$level.shadow'),
          ),
        ),
    };
  }

  static MotionTokens _readMotion(Map<String, Object?> root) {
    const List<String> expected = <String>[
      'durationFast',
      'durationNormal',
      'durationSlow',
      'easingStandard',
      'easingEmphasized',
      'pressScale',
    ];
    _requireExactKeys('motion', _group(root, 'motion'), expected);

    return MotionTokens(
      fastMs: _durationValue(
        'motion.durationFast',
        _value(root, 'motion.durationFast'),
      ),
      normalMs: _durationValue(
        'motion.durationNormal',
        _value(root, 'motion.durationNormal'),
      ),
      slowMs: _durationValue(
        'motion.durationSlow',
        _value(root, 'motion.durationSlow'),
      ),
      standard: _bezierValue(
        'motion.easingStandard',
        _value(root, 'motion.easingStandard'),
      ),
      emphasized: _bezierValue(
        'motion.easingEmphasized',
        _value(root, 'motion.easingEmphasized'),
      ),
      pressScale: _number(
        'motion.pressScale',
        _value(root, 'motion.pressScale'),
      ),
    );
  }

  // -- leaf values ----------------------------------------------------------

  /// Reads the `$value` at [pointer], following `{a.b.c}` aliases.
  ///
  /// An alias that does not resolve, or that resolves in a circle, is a failure
  /// rather than a fallback: a token quietly resolving to nothing is how a
  /// component ends up transparent on one theme only.
  static Object? _value(Map<String, Object?> root, String pointer) {
    final Set<String> seen = <String>{};
    String current = pointer;

    while (true) {
      if (!seen.add(current)) {
        throw TokenFormatException(
          pointer,
          'alias cycle: ${seen.join(' -> ')} -> $current',
        );
      }

      final Map<String, Object?> node = _group(root, current);
      if (!node.containsKey(r'$value')) {
        throw TokenFormatException(current, r'node has no $value');
      }

      final Object? value = node[r'$value'];
      if (value is! String) {
        return value;
      }

      final Match? alias = _alias.firstMatch(value);
      if (alias == null) {
        return value;
      }

      current = alias.group(1)!;
    }
  }

  static String _color(String pointer, Object? value) {
    if (value is! String || !_hex.hasMatch(value)) {
      throw TokenFormatException(
        pointer,
        'expected #RRGGBB or #AARRGGBB (alpha first, Dart order), got "$value"',
      );
    }
    final String digits = value.substring(1).toUpperCase();
    return digits.length == 6 ? '#FF$digits' : '#$digits';
  }

  static double _dimensionValue(String pointer, Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    final Match? match = value is String ? _dimension.firstMatch(value) : null;
    if (match == null) {
      throw TokenFormatException(
        pointer,
        'expected a rem or px dimension, got "$value"',
      );
    }
    final double magnitude = double.parse(match.group(1)!);
    return match.group(2) == 'rem' ? magnitude * remRoot : magnitude;
  }

  static int _durationValue(String pointer, Object? value) {
    final Match? match = value is String ? _duration.firstMatch(value) : null;
    if (match == null) {
      throw TokenFormatException(
        pointer,
        'expected a duration in ms, got "$value"',
      );
    }
    return int.parse(match.group(1)!);
  }

  static List<double> _bezierValue(String pointer, Object? value) {
    final Match? match = value is String ? _bezier.firstMatch(value) : null;
    if (match == null) {
      throw TokenFormatException(
        pointer,
        'expected cubic-bezier(a, b, c, d), got "$value"',
      );
    }
    return <double>[
      for (int group = 1; group <= 4; group++)
        double.parse(match.group(group)!),
    ];
  }

  static double _number(String pointer, Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    throw TokenFormatException(pointer, 'expected a number, got "$value"');
  }

  static TypeStep _typeStep(String pointer, Object? value) {
    if (value is! Map<String, Object?>) {
      throw TokenFormatException(
        pointer,
        'expected a composite typography value',
      );
    }
    for (final String key in <String>[
      'fontSize',
      'lineHeight',
      'fontWeight',
      'letterSpacing',
    ]) {
      if (!value.containsKey(key)) {
        throw TokenFormatException(pointer, 'missing "$key"');
      }
    }
    final double weight = _number('$pointer.fontWeight', value['fontWeight']);
    if (weight % 100 != 0 || weight < 100 || weight > 900) {
      throw TokenFormatException(
        '$pointer.fontWeight',
        'expected a hundred-step weight between 100 and 900, got $weight',
      );
    }
    return TypeStep(
      fontSize: _number('$pointer.fontSize', value['fontSize']),
      lineHeight: _number('$pointer.lineHeight', value['lineHeight']),
      fontWeight: weight.toInt(),
      letterSpacing: _number('$pointer.letterSpacing', value['letterSpacing']),
    );
  }

  static List<ShadowSpec> _shadows(String pointer, Object? value) {
    if (value is! List<Object?>) {
      throw TokenFormatException(pointer, 'expected a list of shadows');
    }
    return <ShadowSpec>[
      for (int index = 0; index < value.length; index++)
        _shadow('$pointer[$index]', value[index]),
    ];
  }

  static ShadowSpec _shadow(String pointer, Object? value) {
    if (value is! Map<String, Object?>) {
      throw TokenFormatException(pointer, 'expected a shadow object');
    }
    return ShadowSpec(
      color: _color('$pointer.color', value['color']),
      opacity: _number('$pointer.opacity', value['opacity']),
      offsetY: _number('$pointer.offsetY', value['offsetY']),
      blur: _number('$pointer.blur', value['blur']),
      spread: _number('$pointer.spread', value['spread']),
    );
  }

  // -- structure ------------------------------------------------------------

  static Map<String, Object?> _group(
    Map<String, Object?> root,
    String pointer,
  ) {
    Object? node = root;
    for (final String segment in pointer.split('.')) {
      if (node is! Map<String, Object?> || !node.containsKey(segment)) {
        throw TokenFormatException(pointer, 'no such node');
      }
      node = node[segment];
    }
    if (node is! Map<String, Object?>) {
      throw TokenFormatException(pointer, 'expected an object');
    }
    return node;
  }

  /// The check that makes an upstream addition loud.
  static void _requireExactKeys(
    String pointer,
    Map<String, Object?> group,
    List<String> expected,
  ) {
    final Set<String> present = group.keys
        .where((String key) => !key.startsWith(r'$'))
        .toSet();
    final Set<String> wanted = expected.toSet();

    final Set<String> unknown = present.difference(wanted);
    if (unknown.isNotEmpty) {
      throw TokenFormatException(
        pointer,
        'unknown token(s) ${_list(unknown)} -- add them to TokenManifest so they '
        'are emitted, or remove them from the token file. A token the generator '
        'does not know about must never be silently dropped.',
      );
    }

    final Set<String> missing = wanted.difference(present);
    if (missing.isNotEmpty) {
      throw TokenFormatException(pointer, 'missing token(s) ${_list(missing)}');
    }
  }

  static void _requireSymmetry(
    String pointer,
    Map<String, Map<String, String>> group,
  ) {
    final Set<String> light = group['light']!.keys.toSet();
    final Set<String> dark = group['dark']!.keys.toSet();
    if (light.difference(dark).isEmpty && dark.difference(light).isEmpty) {
      return;
    }
    throw TokenFormatException(
      pointer,
      'light and dark do not describe the same tokens -- '
      'only in light: ${_list(light.difference(dark))}, '
      'only in dark: ${_list(dark.difference(light))}',
    );
  }

  static String _list(Set<String> names) {
    final List<String> sorted = names.toList()..sort();
    return sorted.join(', ');
  }
}
