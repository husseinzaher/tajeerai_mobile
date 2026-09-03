import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/app_theme.dart';

/// Wraps a widget in the app's real theme.
///
/// Widget tests run against the actual `ThemeData` rather than a stub, so a
/// token that is wrong in one appearance fails a test rather than shipping.
///
/// Deliberately *not* a `ProviderScope`: a test that needs overrides supplies
/// its own scope around this, and nesting a second, override-free scope inside
/// would silently shadow it. See [scoped] for the common case.
Widget wrapWidget(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection textDirection = TextDirection.ltr,
  Size size = const Size(400, 800),
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Directionality(
      textDirection: textDirection,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// [wrapWidget] inside a bare [ProviderScope], for widgets that read no
/// overridden provider.
Widget scoped(
  Widget child, {
  Brightness brightness = Brightness.light,
  TextDirection textDirection = TextDirection.ltr,
  Size size = const Size(400, 800),
}) {
  return ProviderScope(
    child: wrapWidget(
      child,
      brightness: brightness,
      textDirection: textDirection,
      size: size,
    ),
  );
}

/// Pumps [child] in both appearances and runs [expectations] against each.
///
/// Every identity in the web theme remaps the same semantic names, so a
/// component has to be verified in both -- checking only the one you happen to
/// be looking at is how a colour ends up unreadable in dark mode.
Future<void> pumpInBothThemes(
  WidgetTester tester,
  Widget child,
  Future<void> Function(WidgetTester tester, Brightness brightness)
  expectations,
) async {
  for (final brightness in Brightness.values) {
    await tester.pumpWidget(
      wrapWidget(
        // Keyed per appearance so Flutter cannot reuse the previous pass's
        // elements: without it the second pump keeps the first theme's
        // already-built subtree and the assertion reads a stale colour.
        KeyedSubtree(key: ValueKey<Brightness>(brightness), child: child),
        brightness: brightness,
      ),
    );

    // Two frames: one to build, one to let the 150ms token transitions land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await expectations(tester, brightness);
  }
}
