import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled typeface into the test binding.
///
/// Without this every glyph renders as the test font's box, and a golden would
/// encode that — then break the day somebody looked at it. Read from disk
/// rather than through `rootBundle` so the harness does not depend on how the
/// test binding happens to serve assets.
///
/// Tajawal ships no 600 weight; the three faces here are the three the type
/// scale uses. See `assets/fonts/README.md`.
Future<void> loadTajawal() async {
  final FontLoader loader = FontLoader('Tajawal');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
    final Uint8List bytes = File('assets/fonts/Tajawal-$weight.ttf')
        .readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Loads the icon font.
///
/// Icons are a font like any other, and `flutter test` loads none of them, so
/// without this every glyph in a golden is the test font's empty box — which
/// would then be blessed as correct. Read through `rootBundle` with the
/// package-qualified path Flutter itself uses for a font shipped by a package.
Future<void> loadIcons() async {
  final FontLoader loader = FontLoader('packages/lucide_icons_flutter/Lucide');
  loader.addFont(
    rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
  );
  await loader.load();
}

/// Everything a golden needs before it can be trusted.
///
/// Except emoji. `flutter test` carries no emoji font, so a reaction's
/// thumbs-up captures as an empty box. Bundling one would put about 10 MB into
/// the repository to draw it, and loading the machine's own would make the
/// image depend on which machine made it — so the box is the known, stable
/// picture, and a reviewer should read it as "an emoji goes here".
Future<void> loadFonts() async {
  await loadTajawal();
  await loadIcons();
}

/// Sizes the surface to a real phone and renders at 1:1.
///
/// A fixed device pixel ratio keeps a golden generated on one machine
/// comparable with one generated on another.
void useDevice(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// One of the two ways every golden is captured.
typedef GoldenVariant = ({
  String name,
  TextDirection direction,
  Locale locale,
  Brightness brightness,
});

/// English, left to right, light — and Arabic, right to left, dark.
///
/// Two variants rather than the four-way cross-product of direction and
/// appearance. Between them they hold both directions and both appearances —
/// a mirrored icon, a hard-coded left, a colour that only works on white all
/// show in one or the other — at half the images a reviewer has to look at.
const List<GoldenVariant> goldenVariants = <GoldenVariant>[
  (
    name: 'ltr_light',
    direction: TextDirection.ltr,
    locale: Locale('en'),
    brightness: Brightness.light,
  ),
  (
    name: 'rtl_dark',
    direction: TextDirection.rtl,
    locale: Locale('ar'),
    brightness: Brightness.dark,
  ),
];

/// Decodes every image on screen before a capture.
///
/// Text is laid out synchronously; images are not. An asset is read and
/// decoded off the frame, so a golden captured straight after `pump` records an
/// empty box where the logo belongs — and blesses it. Decoding has to happen
/// outside the fake clock, which is what `runAsync` is for.
Future<void> precacheImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final Element element in find.byType(Image).evaluate()) {
      final Image image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pump();
}
