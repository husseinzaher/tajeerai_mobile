@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_registry.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_scaffold.dart';
import 'package:tajeerai_mobile/design_system/showcase/showcase_section.dart';

import '../../support/golden_harness.dart';
import '../../support/widget_harness.dart';

/// The phone every page is captured on.
const double _width = 390;

/// Tall enough to lay any page out whole before it is measured.
const double _measuringHeight = 16000;

/// Pages that are not captured, and why. Every other page is — including one
/// added later, without anybody remembering to list it.
const Map<String, String> _notCaptured = <String, String>{
  'Overlays':
      'its examples are buttons that open something. A closed button is in '
      'Buttons, and the open select sheet has a golden of its own.',
};

/// Pixel captures of the showcase, one page at a time, whole.
///
/// They render `ShowcaseSectionView` rather than a sheet assembled here, so the
/// image is the documentation page and cannot drift from it. Each page is
/// captured top to bottom: a phone-sized capture of a scrolling page holds its
/// first screenful, and everything below that was never pixel-checked at all.
///
/// Two variants per page ([goldenVariants]) on the product preset. Foundations
/// is captured under `aurora` too: a component that reads tokens is correct
/// under any preset that declares them, and the palette page is where a
/// preset's tokens are all on screen at once.
void main() {
  setUpAll(loadFonts);

  final List<ShowcaseSection> sections = showcaseSections();
  final List<ShowcaseSection> captured = <ShowcaseSection>[
    for (final ShowcaseSection section in sections)
      if (!_notCaptured.containsKey(section.title)) section,
  ];

  test('every page left out is one that exists', () {
    expect(<String>{
      for (final ShowcaseSection s in sections) s.title,
    }, containsAll(_notCaptured.keys));
  });

  for (final ShowcaseSection section in captured) {
    // "App shell" would otherwise put a space in a file name.
    final String slug = section.title.toLowerCase().replaceAll(' ', '_');

    for (final GoldenVariant variant in goldenVariants) {
      testWidgets('${slug}_${variant.name}', (WidgetTester tester) async {
        await _captureWhole(
          tester,
          section,
          variant,
          name: '${slug}_${variant.name}',
        );
      });
    }
  }

  final ShowcaseSection foundations = captured.firstWhere(
    (ShowcaseSection s) => s.title == 'Foundations',
  );
  for (final GoldenVariant variant in goldenVariants) {
    testWidgets('foundations_aurora_${variant.name}', (
      WidgetTester tester,
    ) async {
      await _captureWhole(
        tester,
        foundations,
        variant,
        name: 'foundations_aurora_${variant.name}',
        preset: TajeerPreset.aurora,
      );
    });
  }
}

/// Captures [section] whole: a phone's width, and exactly the page's height.
///
/// A page is a ListView, which builds only what is near its viewport. So it is
/// laid out first on a surface tall enough for all of it, measured, and then
/// captured on a surface exactly that tall: no example is cut off, and nothing
/// blank trails the last one.
Future<void> _captureWhole(
  WidgetTester tester,
  ShowcaseSection section,
  GoldenVariant variant, {
  required String name,
  TajeerPreset preset = TajeerPreset.fallback,
}) async {
  Future<double> layOut(double height) async {
    final Size size = Size(_width, height);
    useDevice(tester, size: size);
    await tester.pumpWidget(
      wrapWidget(
        ShowcaseSectionView(section: section),
        preset: preset,
        brightness: variant.brightness,
        textDirection: variant.direction,
        locale: variant.locale,
        size: size,
      ),
    );
    // Never pumpAndSettle: AppSpinner and AppSkeleton repeat() forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The list's padding sliver. Once every example is laid out, its extent is
    // the whole page, padding included.
    final RenderSliver page = tester.renderObject<RenderSliver>(
      find
          .descendant(
            of: find.byType(ShowcaseSectionView),
            matching: find.byType(SliverPadding),
          )
          .first,
    );
    return page.geometry!.scrollExtent.ceilToDouble();
  }

  final double whole = await layOut(_measuringHeight);
  expect(
    whole,
    lessThan(_measuringHeight),
    reason: '${section.title} is taller than the surface it was measured on',
  );

  // Measured again at exactly that height. If anything on the page depended
  // on how tall the screen is, the image would be cut off or trail blank.
  expect(await layOut(whole), whole, reason: section.title);
  await precacheImages(tester);

  // A golden blesses whatever it is handed, overflow stripes included.
  expect(tester.takeException(), isNull);

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../goldens/$name.png'),
  );
}
