import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../display/segmented_control.dart';
import '../display/tabs.dart';
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
          // The real component. This was a private copy until
          // `AppSegmentedControl` existed — which is the right order: the
          // showcase is allowed to be the thing that notices a primitive is
          // missing, never the thing that keeps its own version of one.
          AppSegmentedControl<TajeerPreset>(
            value: preset,
            onChanged: onPreset,
            options: <TajeerPreset, String>{
              for (final TajeerPreset p in TajeerPreset.values) p: p.name,
            },
          ),
          AppSegmentedControl<ThemeMode>(
            value: mode,
            onChanged: onMode,
            options: const <ThemeMode, String>{
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
              ThemeMode.system: 'System',
            },
          ),
          AppSegmentedControl<TextDirection>(
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
    // Also the real component. What was hand-rolled here is exactly what
    // AppTabs is: a scrollable row of labelled destinations with an underline
    // on the selected one.
    return ColoredBox(
      color: context.colors.surface,
      child: AppTabs(
        index: index,
        onChanged: onChanged,
        tabs: <AppTab>[
          for (final ShowcaseSection section in sections)
            AppTab(label: section.title, icon: section.icon),
        ],
      ),
    );
  }
}
