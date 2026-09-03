import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/events/auth_events.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import 'bootstrap/dependencies.dart';
import 'localization/locale_manager.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// The application widget.
///
/// It owns the *composition* of the running app -- theme, locale, router --
/// and one piece of lifecycle that has nowhere else to live: connecting the
/// session to the socket. That wiring is not business logic; it is the
/// application's start-up sequence, and both halves of it belong to features
/// that must not depend on each other.
class TajeerApp extends ConsumerStatefulWidget {
  const TajeerApp({super.key});

  @override
  ConsumerState<TajeerApp> createState() => _TajeerAppState();
}

class _TajeerAppState extends ConsumerState<TajeerApp> {
  @override
  void initState() {
    super.initState();

    // After the first frame, so the splash route is on screen while the
    // session is resolved rather than the app appearing to hang on a white
    // rectangle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireSessionToRealtime();
      ref.read(authControllerProvider.notifier).restore();
    });
  }

  /// Starts and stops the realtime stack with the session.
  ///
  /// The auth feature announces [SignedIn]/[SignedOut]; this reacts. Auth does
  /// not know a socket exists, and the conversations feature does not know how
  /// a session is established -- the two are joined here, at the composition
  /// root, which is the only place allowed to know about both.
  void _wireSessionToRealtime() {
    final coordinator = ref.read(sessionCoordinatorProvider);

    coordinator.events.listen((event) async {
      switch (event) {
        case SignedIn():
          final socket = ref.read(socketManagerProvider);
          final sync = ref.read(conversationSyncProvider);
          final handler = ref.read(conversationSocketHandlerProvider);

          // The handler subscribes before the socket opens, so no frame
          // arriving during the handshake is missed.
          handler.attach(socket.events);

          sync
            ..bindTo(
              connections: socket.connections,
              connectionStates: socket.states,
            )
            ..trackOutbox();

          await socket.start();

        case SignedOut():
          await ref.read(socketManagerProvider).stop();

        case SessionRefreshed():
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Tajeer AI',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The OS decides. Both themes are complete, so following the system is
      // the correct default rather than a placeholder.
      themeMode: ThemeMode.system,
      locale: locale.locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
