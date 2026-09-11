@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_registry.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_scaffold.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_section.dart';

import '../support/golden_harness.dart';
import '../support/widget_harness.dart';

/// Pixel captures of the showcase's own sections.
///
/// They render `ShowcaseSectionView` rather than a sheet assembled here. An
/// earlier version of this file built its own arrangement of components, which
/// made it a second, quieter implementation of exactly what the showcase
/// exists to be — and one that could drift from it without anything failing.
///
/// Deliberately few. A handful of images a person actually reviews beats two
/// hundred nobody looks at, and a token change *should* invalidate them:
/// looking at the regenerated image is the point.
void main() {
  setUpAll(loadFonts);

  final List<ShowcaseSection> sections = showcaseSections();

  /// The two that carry the most of the identity between them: the palette and
  /// the type scale, and the controls a member actually touches.
  final List<ShowcaseSection> captured = <ShowcaseSection>[
    sections.firstWhere((ShowcaseSection s) => s.title == 'Foundations'),
    sections.firstWhere((ShowcaseSection s) => s.title == 'Forms'),
    sections.firstWhere((ShowcaseSection s) => s.title == 'Display'),
    sections.firstWhere((ShowcaseSection s) => s.title == 'Authentication'),
    sections.firstWhere((ShowcaseSection s) => s.title == 'App shell'),
  ];

  for (final ShowcaseSection section in captured) {
    for (final TajeerPreset preset in TajeerPreset.values) {
      for (final Brightness brightness in Brightness.values) {
        // "App shell" would otherwise put a space in a file name.
        final String slug = section.title.toLowerCase().replaceAll(' ', '_');
        final String name = '${slug}_${preset.name}_${brightness.name}';

        testWidgets(name, (WidgetTester tester) async {
          useDevice(tester);
          await tester.pumpWidget(
            wrapWidget(
              ShowcaseSectionView(section: section),
              preset: preset,
              brightness: brightness,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              size: const Size(390, 844),
            ),
          );
          // Never pumpAndSettle: AppSpinner and AppSkeleton repeat() forever.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await precacheImages(tester);

          // A golden blesses whatever it is handed, overflow stripes included.
          expect(tester.takeException(), isNull);

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../goldens/$name.png'),
          );
        });
      }
    }
  }
}
