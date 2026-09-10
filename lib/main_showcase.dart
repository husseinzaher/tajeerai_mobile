import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/theme/theme.dart';
import 'design_system/design_system.dart';
import 'design_system/showcase/showcase_app.dart';

/// A second entry point that runs nothing but the design system.
///
///     flutter run -t lib/main_showcase.dart -d chrome
///
/// It exists because the real `main.dart` opens a drift database, a socket and
/// a secure store before it shows anything — none of which a browser has, and
/// none of which the design system depends on. Twenty lines here buy a preview
/// surface a designer can open without a device.
///
/// It is not a second app. It mounts the same [ShowcaseApp] the in-app
/// `/design-system` route does, which mounts the same production components
/// every screen does.
void main() {
  runApp(const _ShowcaseRoot());
}

class _ShowcaseRoot extends StatelessWidget {
  const _ShowcaseRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tajeer AI — Design System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Spelled out rather than read from `AppLocale`: that enum lives beside
      // the locale manager, which reaches the dependency graph, and the whole
      // point of this entry point is that the design system needs none of it.
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppDesignSystemLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The same ceiling the real app applies, so a control that clips at 2x
      // clips here too rather than only on somebody's phone.
      builder: (BuildContext context, Widget? child) =>
          MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: TajeerTypography.maxTextScale,
            child: child!,
          ),
      home: const ShowcaseApp(),
    );
  }
}
