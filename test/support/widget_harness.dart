import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tajeerai_mobile/app/localization/locale_manager.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/design_system.dart';

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
  TajeerPreset preset = TajeerPreset.fallback,
  bool disableAnimations = false,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    // Off, or every golden carries a red ribbon across its top corner and the
    // first thing anybody reviewing one sees is the banner.
    debugShowCheckedModeBanner: false,
    theme: AppTheme.of(preset, brightness),
    // The delegates are mounted so a component reads the same copy it will in
    // production. `AppDesignSystemLocalizations` falls back to English without
    // them, which is what keeps a bare pump working -- but a test that asserts
    // on Arabic copy needs them present.
    locale: locale,
    supportedLocales: AppLocale.supported,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppDesignSystemLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: textDirection,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
          textScaler: textScaler,
        ),
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
  TajeerPreset preset = TajeerPreset.fallback,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: wrapWidget(
      child,
      brightness: brightness,
      textDirection: textDirection,
      size: size,
      preset: preset,
      locale: locale,
    ),
  );
}

/// Pumps [child] in both appearances and runs [expectations] against each.
///
/// Every preset remaps the same semantic names, so a component has to be
/// verified in both appearances -- checking only the one you happen to be
/// looking at is how a colour ends up unreadable in dark mode.
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

/// Pumps [child] in both directions and runs [expectations] against each.
///
/// The mirror image of [pumpInBothThemes], for the other axis this app has to
/// be right in. Arabic is the default locale, so a layout that only works in
/// LTR is broken for most of the people using it.
Future<void> pumpInBothDirections(
  WidgetTester tester,
  Widget child,
  Future<void> Function(WidgetTester tester, TextDirection direction)
  expectations, {
  Brightness brightness = Brightness.light,
}) async {
  for (final direction in TextDirection.values) {
    await tester.pumpWidget(
      wrapWidget(
        KeyedSubtree(key: ValueKey<TextDirection>(direction), child: child),
        brightness: brightness,
        textDirection: direction,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await expectations(tester, direction);
  }
}
