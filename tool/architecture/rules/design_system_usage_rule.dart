import '../architecture_rule.dart';
import '../path_classifier.dart';
import '../source_text.dart';

/// Whether [file] consumes the design system rather than being part of it.
///
/// Raw values and raw Material widgets belong in exactly two places: the
/// system that wraps them, and the theme that defines them. Every other file
/// under `lib/` — features, the authenticated shell, the router, `main.dart` —
/// is a consumer.
bool _isConsumer(FileLocation file) =>
    file.layer != Layer.designSystem && !file.path.startsWith('lib/app/theme/');

/// One shape RULE 34 looks for, and what to write instead.
class _RawValue {
  const _RawValue({
    required this.pattern,
    required this.reason,
    required this.alternative,
    this.onlyWithNumbers = false,
  });

  final RegExp pattern;
  final String reason;
  final String alternative;

  /// Whether a match is a violation only when its arguments hold a number.
  ///
  /// `EdgeInsets.all(TajeerSpacing.md)` is the scale being used and
  /// `EdgeInsets.all(16)` is the scale being bypassed; the constructor is the
  /// same. Zero is not a design value, so it passes.
  final bool onlyWithNumbers;
}

const String _colourAlternative =
    'A semantic token: context.colors.textPrimary, context.colors.surface, '
    'context.colors.dangerDefault.';

final List<_RawValue> _rawValues = <_RawValue>[
  _RawValue(
    pattern: RegExp(r'(?<![\w$])Color(?:\.from\w*)?\s*\('),
    reason:
        'A colour written into a screen does not follow the preset or the '
        'appearance. It is right in one of the four themes and wrong in the '
        'other three.',
    alternative: _colourAlternative,
  ),
  _RawValue(
    pattern: RegExp(r'(?<![\w$])(?:Colors|CupertinoColors)\.\w+'),
    reason:
        "Material's palette is not this app's. Colors.red is a colour with no "
        'meaning, and nothing re-tints it when the theme changes.',
    alternative: _colourAlternative,
  ),
  _RawValue(
    pattern: RegExp(r'(?<![\w$])font(?:Size|Family)\s*:'),
    reason:
        'A hand-set size or family is a type step nobody can find. It does '
        'not move with the scale, and it drops the fallback the scale carries '
        'for Arabic.',
    alternative:
        'A step from the type scale: context.type.bodyMd, '
        'context.type.labelSm.',
  ),
  _RawValue(
    pattern: RegExp(
      r'(?<![\w$])(?:BorderRadius|BorderRadiusDirectional|Radius)\.circular\s*\(',
    ),
    onlyWithNumbers: true,
    reason:
        'An off-scale radius is how two cards on one screen end up with '
        'different corners.',
    alternative: 'A radius token: TajeerRadii.mdAll, TajeerRadii.lgAll.',
  ),
  _RawValue(
    pattern: RegExp(
      r'(?<![\w$])EdgeInsets(?:Directional)?\.'
      r'(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(',
    ),
    onlyWithNumbers: true,
    reason:
        'A number of pixels is a spacing step the scale does not have, and '
        'the next screen picks a different one.',
    alternative:
        'Spacing tokens: '
        'EdgeInsetsDirectional.symmetric(horizontal: TajeerSpacing.md).',
  ),
];

/// A number literal that is not part of a name like `xl2`.
final RegExp _number = RegExp(r'(?<![\w$.])(\d+(?:\.\d+)?|\.\d+)(?![\w.])');

bool _holdsNumber(String arguments) => _number
    .allMatches(arguments)
    .any((RegExpMatch match) => double.parse(match.group(1)!) != 0);

/// The offending text as it is written, arguments included, on one line.
String _excerpt(ArchitectureContext context, String code, RegExpMatch match) {
  final String source = context.source;
  int end = match.end;
  if (match.group(0)!.endsWith('(')) {
    end += SourceText.argumentsAt(code, match.end - 1).length + 1;
  }
  return source
      .substring(match.start, end > source.length ? source.length : end)
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// RULE 34 — outside the design system and the theme, no raw design values.
///
/// The enforceable half of "no hardcoded colours" and of "a screen does not
/// bring its own spacing, radius or type". It flags a `Color(…)` or
/// `Colors.x`, a `fontSize:` or `fontFamily:`, and a `BorderRadius.circular`
/// or `EdgeInsets` that holds a number where a token belongs.
///
/// **A heuristic, and it says so.** The rules beside it read resolved imports;
/// this one reads source text, with comments and string contents blanked by
/// [SourceText.codeOnly], and matches shapes. It catches a prefixed import
/// (`m.Colors.red`). It does not catch a number reached through a local
/// constant (`const gap = 16;`), or a colour built in another file and passed
/// in. That is weaker than a proof — and still the only thing between review
/// and a hex in a screen. A heuristic that admits its gaps is worth more than
/// one that pretends to have none.
class RawDesignValueRule implements ArchitectureRule {
  const RawDesignValueRule();

  @override
  String get id => 'RULE 34';

  @override
  String get description =>
      'Outside the Design System and the theme, no raw colour, type, radius or '
      'spacing values.';

  @override
  List<Violation> check(ArchitectureContext context) {
    if (!_isConsumer(context.file) || context.source.isEmpty) {
      return const <Violation>[];
    }

    final String code = SourceText.codeOnly(context.source);
    final List<Violation> violations = <Violation>[];

    for (final _RawValue raw in _rawValues) {
      for (final RegExpMatch match in raw.pattern.allMatches(code)) {
        if (raw.onlyWithNumbers &&
            !_holdsNumber(SourceText.argumentsAt(code, match.end - 1))) {
          continue;
        }

        violations.add(
          Violation(
            rule: '$id - $description',
            source: context.file.path,
            forbiddenDependency: _excerpt(context, code, match),
            line: SourceText.lineOf(code, match.start),
            reason: raw.reason,
            allowedAlternative: raw.alternative,
          ),
        );
      }
    }

    return violations
      ..sort((Violation a, Violation b) => a.line!.compareTo(b.line!));
  }
}

/// The Material widgets the design system already wraps, and the wrapper.
///
/// The functions at the end open one, so they are the same bypass by another
/// route.
const Map<String, String> _wrapped = <String, String>{
  'ActionChip': 'AppChip',
  'AlertDialog': 'AppDialog',
  'AppBar': 'AppToolbar',
  'Badge': 'AppBadge',
  'BottomNavigationBar': 'AppBottomNavigation',
  'BottomSheet': 'AppBottomSheet',
  'Card': 'AppCard',
  'Checkbox': 'AppCheckbox',
  'CheckboxListTile': 'AppCheckbox',
  'Chip': 'AppChip',
  'ChoiceChip': 'AppChip',
  'CircleAvatar': 'AppAvatar',
  'CircularProgressIndicator': 'AppSpinner',
  'Dialog': 'AppDialog',
  'Divider': 'AppSeparator',
  'Drawer': 'AppNavigationDrawer',
  'DropdownButton': 'AppSelect',
  'DropdownButtonFormField': 'AppSelect',
  'DropdownMenu': 'AppSelect',
  'ElevatedButton': 'AppButton',
  'FilledButton': 'AppButton',
  'FilterChip': 'AppChip',
  'IconButton': 'AppButton.icon',
  'InputChip': 'AppChip',
  'LinearProgressIndicator': 'AppProgressBar',
  'ListTile': 'AppListItem',
  'NavigationBar': 'AppBottomNavigation',
  'NavigationDrawer': 'AppNavigationDrawer',
  'OutlinedButton': 'AppButton(variant: AppButtonVariant.outline)',
  'PopupMenuButton': 'AppActionSheet',
  'Radio': 'AppRadioGroup',
  'RadioListTile': 'AppRadioGroup',
  'Scaffold':
      'AppScaffold — or AppShell and AppConversationShell, for the frames '
      'they own',
  'SegmentedButton': 'AppSegmentedControl',
  'SimpleDialog': 'AppDialog',
  'SliverAppBar': 'AppToolbar',
  'SnackBar': 'AppSnackbar.show',
  'Switch': 'AppSwitch',
  'SwitchListTile': 'AppSwitch',
  'TabBar': 'AppTabs',
  'TextButton': 'AppButton(variant: AppButtonVariant.ghost)',
  'TextField': 'AppTextField',
  'TextFormField': 'AppTextField',
  'Tooltip': 'AppTooltip',
  'VerticalDivider': 'AppSeparator.vertical',
  'showBottomSheet': 'AppBottomSheet.show',
  'showDialog': 'AppDialog.show, or AppDialog.confirm',
  'showModalBottomSheet': 'AppBottomSheet.show',
  'showSnackBar': 'AppSnackbar.show',
};

/// A call to one of [_wrapped]: with type arguments, a named constructor or a
/// prefixed import. `Scaffold.of(context)` is a lookup, not a construction.
final RegExp _construction = () {
  // Longest first, so `RadioListTile` is reported as itself and not as `Radio`.
  final List<String> names = _wrapped.keys.toList()
    ..sort((String a, String b) => b.length.compareTo(a.length));
  final String alternatives = names.join('|');
  return RegExp(
    '(?<![\\w\$])($alternatives)'
    r'\s*(?:<[^()]*?>)?\s*(?:\.(?!of\b|maybeOf\b)[A-Za-z_]\w*)?\s*\(',
  );
}();

/// RULE 35 — outside the design system, never build a Material widget it
/// already wraps.
///
/// The enforceable half of "no one-off feature UI". The case it was written
/// against is `login_form.dart` wrapping a raw `Checkbox` so its label could be
/// tapped: it worked, it looked nearly right, and it carried its own target
/// size and its own idea of a label. That is why such a thing survives review.
///
/// It holds wherever RULE 34 does, not only under `features/`: the
/// authenticated shell and the router consume the design system too.
///
/// The same kind of heuristic as RULE 34, owed the same honesty. It matches a
/// call by name on text with comments and strings blanked. A tear-off
/// (`Card.new`) or a typedef that renames a widget walks past it.
class MaterialWidgetRule implements ArchitectureRule {
  const MaterialWidgetRule();

  @override
  String get id => 'RULE 35';

  @override
  String get description =>
      'Outside the Design System and the theme, never build a Material widget '
      'the Design System wraps.';

  @override
  List<Violation> check(ArchitectureContext context) {
    if (!_isConsumer(context.file) || context.source.isEmpty) {
      return const <Violation>[];
    }

    final String code = SourceText.codeOnly(context.source);

    return <Violation>[
      for (final RegExpMatch match in _construction.allMatches(code))
        Violation(
          rule: '$id - $description',
          source: context.file.path,
          forbiddenDependency: match.group(0)!.replaceAll(RegExp(r'\s+'), ''),
          line: SourceText.lineOf(code, match.start),
          reason:
              'The Design System already wraps ${match.group(1)}, with the '
              'tokens, the touch target, the semantics and both directions. '
              'One built here is the one-off UI Design System First forbids.',
          allowedAlternative:
              '${_wrapped[match.group(1)]}, from design_system.dart. If it '
              'cannot do what this screen needs, extend it there.',
        ),
    ];
  }
}
