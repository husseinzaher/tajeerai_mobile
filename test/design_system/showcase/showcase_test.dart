import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_app.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_registry.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_scaffold.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_section.dart';

import '../../support/widget_harness.dart';

/// The showcase, used as a test harness rather than only as documentation.
///
/// Every section is pumped across four independent axes rather than their
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

List<String> _showcaseSources() {
  const List<String> paths = <String>[
    'lib/design_system/showcase/showcase_app.dart',
    'lib/design_system/showcase/showcase_scaffold.dart',
    'lib/design_system/showcase/showcase_section.dart',
    'lib/design_system/showcase/showcase_registry.dart',
    'lib/design_system/showcase/sections/foundations_section.dart',
    'lib/design_system/showcase/sections/components_section.dart',
    'lib/design_system/showcase/sections/authentication_section.dart',
    'lib/design_system/showcase/sections/shell_section.dart',
  ];
  return <String>[
    for (final String path in paths) File(path).readAsStringSync(),
  ];
}

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
            await _pump(
              tester,
              wrapWidget(
                KeyedSubtree(
                  key: ValueKey<String>('${preset.name}-${brightness.name}'),
                  child: ShowcaseSectionView(section: section),
                ),
                preset: preset,
                brightness: brightness,
                size: const Size(390, 844),
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${section.title} in ${preset.name}/${brightness.name}',
            );
          }
        }
      });

      testWidgets('${section.title} — both directions', (
        WidgetTester tester,
      ) async {
        for (final TextDirection direction in TextDirection.values) {
          await _pump(
            tester,
            wrapWidget(
              KeyedSubtree(
                key: ValueKey<TextDirection>(direction),
                child: ShowcaseSectionView(section: section),
              ),
              textDirection: direction,
              locale: direction == TextDirection.rtl
                  ? const Locale('ar')
                  : const Locale('en'),
              size: const Size(390, 844),
            ),
          );
          expect(tester.takeException(), isNull, reason: direction.name);
        }
      });

      testWidgets('${section.title} — every phone width, and a tablet', (
        WidgetTester tester,
      ) async {
        for (final double width in <double>[360, 390, 430, 768]) {
          await _pump(
            tester,
            wrapWidget(
              KeyedSubtree(
                key: ValueKey<double>(width),
                child: ShowcaseSectionView(section: section),
              ),
              size: Size(width, 844),
            ),
          );
          expect(tester.takeException(), isNull, reason: '${width}px');
        }
      });

      testWidgets('${section.title} — scaled text does not clip', (
        WidgetTester tester,
      ) async {
        // The enforceable half of "no fixed-height container holds scalable
        // text". A control that pins its height fails here rather than on
        // somebody's phone with large type turned on.
        for (final double scale in <double>[1.3, 2]) {
          await _pump(
            tester,
            wrapWidget(
              KeyedSubtree(
                key: ValueKey<double>(scale),
                child: ShowcaseSectionView(section: section),
              ),
              textScaler: TextScaler.linear(scale),
              size: const Size(390, 844),
            ),
          );
          expect(tester.takeException(), isNull, reason: 'text scale $scale');
        }
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

    test('no showcase file imports a feature', () {
      for (final String source in _showcaseSources()) {
        expect(source.contains('features/'), isFalse);
      }
    });
  });
}
