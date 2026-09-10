import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'showcase_registry.dart';
import 'showcase_scaffold.dart';
import 'showcase_section.dart';

/// The design system's own documentation surface.
///
/// It renders the **production** components. There is no second implementation
/// anywhere in this directory — the only thing it adds is the state a
/// controlled component needs, exactly as a screen would, and the switchers
/// that let one page be seen in every combination the system has to survive.
///
/// It applies its own `Theme` and `Directionality` rather than mounting a
/// second `MaterialApp`: a nested app would bring its own navigator, and the
/// sheets and dialogs opened from here would then be trapped inside it.
class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  TajeerPreset _preset = TajeerPreset.fallback;
  ThemeMode _mode = ThemeMode.system;
  TextDirection _direction = TextDirection.rtl;
  int _section = 0;

  Brightness get _brightness => switch (_mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    // Genuinely live: "System" follows the platform rather than aliasing light.
    ThemeMode.system => MediaQuery.platformBrightnessOf(context),
  };

  @override
  Widget build(BuildContext context) {
    final List<ShowcaseSection> sections = showcaseSections();
    final ThemeData theme = AppTheme.of(_preset, _brightness);

    return Theme(
      data: theme,
      child: Directionality(
        textDirection: _direction,
        // `locale:` only. Passing `delegates:` here would REPLACE the
        // inherited list rather than add to it, and everything below would
        // lose MaterialLocalizations -- which fails at runtime, not at compile
        // time, and only once something asks for a tooltip.
        child: Localizations.override(
          context: context,
          locale: _direction == TextDirection.rtl
              ? const Locale('ar')
              : const Locale('en'),
          child: Builder(
            builder: (BuildContext context) => Scaffold(
              backgroundColor: context.colors.background,
              body: SafeArea(
                child: Column(
                  children: <Widget>[
                    _Controls(
                      preset: _preset,
                      mode: _mode,
                      direction: _direction,
                      onPreset: (TajeerPreset p) => setState(() => _preset = p),
                      onMode: (ThemeMode m) => setState(() => _mode = m),
                      onDirection: (TextDirection d) =>
                          setState(() => _direction = d),
                    ),
                    _SectionTabs(
                      sections: sections,
                      index: _section,
                      onChanged: (int i) => setState(() => _section = i),
                    ),
                    Expanded(
                      child: ShowcaseSectionView(section: sections[_section]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.preset,
    required this.mode,
    required this.direction,
    required this.onPreset,
    required this.onMode,
    required this.onDirection,
  });

  final TajeerPreset preset;
  final ThemeMode mode;
  final TextDirection direction;
  final ValueChanged<TajeerPreset> onPreset;
  final ValueChanged<ThemeMode> onMode;
  final ValueChanged<TextDirection> onDirection;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(TajeerSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Wrap(
        spacing: TajeerSpacing.sm,
        runSpacing: TajeerSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _Segmented<TajeerPreset>(
            value: preset,
            onChanged: onPreset,
            options: <TajeerPreset, String>{
              for (final TajeerPreset p in TajeerPreset.values) p: p.name,
            },
          ),
          _Segmented<ThemeMode>(
            value: mode,
            onChanged: onMode,
            options: const <ThemeMode, String>{
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
              ThemeMode.system: 'System',
            },
          ),
          _Segmented<TextDirection>(
            value: direction,
            onChanged: onDirection,
            options: const <TextDirection, String>{
              TextDirection.rtl: 'RTL',
              TextDirection.ltr: 'LTR',
            },
          ),
        ],
      ),
    );
  }
}

/// A local control, not a design-system component.
///
/// `AppSegmentedControl` does not exist yet. When it does this is deleted and
/// the showcase uses it — which is the right order: the showcase is allowed to
/// be the thing that notices a primitive is missing, never the thing that
/// keeps a private copy of one.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: TajeerRadii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final MapEntry<T, String> option in options.entries)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(option.key),
              child: AnimatedContainer(
                duration: context.motion.fast,
                curve: context.motion.standard,
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: TajeerSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: option.key == value
                      ? colors.primary
                      : Colors.transparent,
                  borderRadius: TajeerRadii.fullAll,
                ),
                child: Text(
                  option.value,
                  style: context.type.labelSm.copyWith(
                    color: option.key == value
                        ? colors.primaryForeground
                        : colors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.sections,
    required this.index,
    required this.onChanged,
  });

  final List<ShowcaseSection> sections;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TajeerSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < sections.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: TajeerSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      bottom: BorderSide(
                        color: i == index ? colors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    spacing: TajeerSpacing.xs2,
                    children: <Widget>[
                      Icon(
                        sections[i].icon,
                        size: 16,
                        color: i == index
                            ? colors.textPrimary
                            : colors.textMuted,
                      ),
                      Text(
                        sections[i].title,
                        style: context.type.labelMd.copyWith(
                          color: i == index
                              ? colors.textPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
