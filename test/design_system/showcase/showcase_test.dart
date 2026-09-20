import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/showcase/showcase_app.dart';
import 'package:TajeerAi/design_system/showcase/showcase_registry.dart';
import 'package:TajeerAi/design_system/showcase/showcase_scaffold.dart';
import 'package:TajeerAi/design_system/showcase/showcase_section.dart';

import '../../support/widget_harness.dart';

/// The showcase, used as a test harness rather than only as documentation.
///
/// Every section is pumped across five independent axes rather than their
/// cross-product — the product would be hundreds of cases for very little more
/// signal. `takeException` is the assertion that earns its keep: it catches
/// RenderFlex overflows, missing Directionality, missing Material ancestors and
/// null-check crashes in a variant nobody pumped by hand.
///
/// **Never `pumpAndSettle`.** `AppSpinner` and `AppSkeleton` call `repeat()` in
/// `initState`, so a settle waits forever. Two pumps, for the same reason
/// `pumpInBothThemes` uses two.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(child);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// How tall a section's surface is in the smoke test.
///
/// `ShowcaseSectionView` is a ListView, and a ListView builds only what is near
/// its viewport. At a phone's real height most of a section's examples were
/// never built, so nothing in them could throw: every axis below was checking
/// the first screenful. This is not a claim about any device. It is a height
/// at which every example is laid out, and [_pumpSection] fails the day it
/// stops being enough.
const double _tall = 16000;

/// Pumps one section [width] logical pixels wide, tall enough to build all of
/// it, and checks that nothing threw.
///
/// The width is set on the test view, not only on `MediaQuery`. A size handed
/// to `MediaQuery` alone changes what a widget *reads* and nothing about the
/// constraints it is laid out in — which is how a "360px" axis once laid every
/// section out at the test binding's default 800.
Future<void> _pumpSection(
  WidgetTester tester,
  ShowcaseSection section, {
  required String variant,
  double width = 390,
  TajeerPreset preset = TajeerPreset.fallback,
  Brightness brightness = Brightness.light,
  TextDirection textDirection = TextDirection.ltr,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) async {
  final Size size = Size(width, _tall);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await _pump(
    tester,
    wrapWidget(
      KeyedSubtree(
        key: ValueKey<String>(variant),
        child: ShowcaseSectionView(section: section),
      ),
      preset: preset,
      brightness: brightness,
      textDirection: textDirection,
      locale: locale,
      textScaler: textScaler,
      disableAnimations: disableAnimations,
      size: size,
    ),
  );

  expect(tester.takeException(), isNull, reason: '${section.title}, $variant');
  expect(
    find.text(section.examples.last.name),
    findsWidgets,
    reason:
        '${section.title}, $variant: the last example was never built, so '
        'the checks covered part of the section. Raise _tall.',
  );
}

/// Every Dart file under showcase/, found rather than listed, so a section
/// added later is held to the checks below without anybody remembering to add
/// it here.
List<String> _showcaseSources() => <String>[
  for (final FileSystemEntity entity in Directory(
    'lib/design_system/showcase',
  ).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart'))
      entity.readAsStringSync(),
];

void main() {
  final List<ShowcaseSection> sections = showcaseSections();

  test('the registry is not empty, so the loops below assert something', () {
    expect(sections, isNotEmpty);
    expect(sections.expand((ShowcaseSection s) => s.examples), isNotEmpty);
  });

  group('every section survives', () {
    for (final ShowcaseSection section in sections) {
      testWidgets('${section.title} — each preset and appearance', (
        WidgetTester tester,
      ) async {
        for (final TajeerPreset preset in TajeerPreset.values) {
          for (final Brightness brightness in Brightness.values) {
            await _pumpSection(
              tester,
              section,
              variant: '${preset.name}/${brightness.name}',
              preset: preset,
              brightness: brightness,
            );
          }
        }
      });

      testWidgets('${section.title} — both directions', (
        WidgetTester tester,
      ) async {
        for (final TextDirection direction in TextDirection.values) {
          await _pumpSection(
            tester,
            section,
            variant: direction.name,
            textDirection: direction,
            locale: direction == TextDirection.rtl
                ? const Locale('ar')
                : const Locale('en'),
          );
        }
      });

      testWidgets('${section.title} — every phone width, and a tablet', (
        WidgetTester tester,
      ) async {
        for (final double width in <double>[360, 390, 430, 768]) {
          await _pumpSection(
            tester,
            section,
            variant: '${width}px',
            width: width,
          );
        }
      });

      testWidgets('${section.title} — scaled text does not clip', (
        WidgetTester tester,
      ) async {
        // The enforceable half of "no fixed-height container holds scalable
        // text". A control that pins its height fails here rather than on
        // somebody's phone with large type turned on.
        for (final double scale in <double>[1.3, 2]) {
          await _pumpSection(
            tester,
            section,
            variant: 'text scale $scale',
            textScaler: TextScaler.linear(scale),
          );
        }
      });

      testWidgets('${section.title} — with animations turned off', (
        WidgetTester tester,
      ) async {
        // Reduced motion swaps what `context.motion` returns for zero
        // durations and no press scale. A component that quietly assumed
        // time passes breaks only for the people who turned animations off.
        await _pumpSection(
          tester,
          section,
          variant: 'reduced motion',
          disableAnimations: true,
        );
      });
    }
  });

  group('the shell', () {
    testWidgets('opens on the first section and can reach the others', (
      WidgetTester tester,
    ) async {
      await _pump(tester, wrapWidget(const ShowcaseApp()));

      expect(find.text(sections.first.title), findsWidgets);

      await tester.tap(find.text(sections[1].title).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the preset switcher really changes the palette', (
      WidgetTester tester,
    ) async {
      await _pump(tester, wrapWidget(const ShowcaseApp()));

      Color canvas() =>
          tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor!;

      final Color before = canvas();
      await tester.tap(find.text(TajeerPreset.aurora.name));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        canvas(),
        isNot(before),
        reason: 'switching preset did not repaint the canvas',
      );
    });

    testWidgets('the direction switcher really flips the layout', (
      WidgetTester tester,
    ) async {
      await _pump(tester, wrapWidget(const ShowcaseApp()));

      // It opens RTL: Arabic is the default locale, so that is the state worth
      // seeing first.
      expect(
        Directionality.of(tester.element(find.byType(ShowcaseSectionView))),
        TextDirection.rtl,
      );

      await tester.tap(find.text('LTR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        Directionality.of(tester.element(find.byType(ShowcaseSectionView))),
        TextDirection.ltr,
      );
    });

    testWidgets('the appearance switcher really changes brightness', (
      WidgetTester tester,
    ) async {
      await _pump(tester, wrapWidget(const ShowcaseApp()));

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        Theme.of(tester.element(find.byType(ShowcaseSectionView))).brightness,
        Brightness.dark,
      );
    });
  });

  group('it stays documentation, not a second implementation', () {
    test('no example builds a widget the design system does not ship', () {
      // Enforced structurally rather than by review: a private widget declared
      // under showcase/ is either a demo holding state a screen would hold, or
      // it is a component that escaped the design system. The names below are
      // the ones allowed to be the former.
      const List<String> allowed = <String>[
        'Showcase',
        '_Swatches',
        '_TypeScale',
        '_Scale',
        '_Radii',
        '_Elevation',
        '_Example',
        '_Controls',
        '_SectionTabs',
        '_SelectDemo',
        '_ChipsDemo',
        '_ListDemo',
        '_TabsDemo',
        '_SearchableSelectDemo',
        '_TogglesDemo',
        '_RadioDemo',
        '_ToolbarSearchDemo',
        '_DrawerDemo',
        '_BottomNavDemo',
        '_ShellDemo',
        '_ComposerDemo',
        '_VoiceDemo',
        '_AudioDemo',
        '_ActionsDemo',
        '_ThreadDemo',
      ];

      final RegExp declaration = RegExp(
        r'^class (\w+) extends State(?:less|ful)Widget',
        multiLine: true,
      );

      for (final String source in _showcaseSources()) {
        for (final RegExpMatch match in declaration.allMatches(source)) {
          final String name = match.group(1)!;
          expect(
            allowed.any(name.startsWith),
            isTrue,
            reason:
                '$name is declared under showcase/. If it is a component it '
                'belongs in the design system; if it is a demo, add it to the '
                'allowed list and say why.',
          );
        }
      }
    });

    test('every widget the design system exports has a page', () {
      // The other half of documentation: a component nobody can find on a
      // showcase page is one the next screen rebuilds for itself. Read the
      // barrel, find every public widget in the files it exports, and look
      // for its name.
      final String showcase = _showcaseSources().join('\n');
      final String barrel = File('lib/design_system/design_system.dart')
          .readAsStringSync();
      final RegExp export = RegExp(r"^export '([^']+)';", multiLine: true);
      final RegExp widget = RegExp(
        r'^class (App\w+)[^{]*\bextends (?:StatelessWidget|StatefulWidget)\b',
        multiLine: true,
      );

      final List<String> declared = <String>[
        for (final RegExpMatch file in export.allMatches(barrel))
          for (final RegExpMatch match in widget.allMatches(
            File('lib/design_system/${file.group(1)}').readAsStringSync(),
          ))
            match.group(1)!,
      ];
      final List<String> missing = <String>[
        for (final String name in declared)
          if (!RegExp('\\b$name\\b').hasMatch(showcase)) name,
      ];

      expect(declared, isNotEmpty);
      expect(
        missing,
        isEmpty,
        reason:
            'Exported, and on no showcase page. Add an example beside the '
            'family it belongs to.',
      );
    });

    test('no showcase file imports a feature', () {
      for (final String source in _showcaseSources()) {
        expect(source.contains('features/'), isFalse);
      }
    });
  });
}
