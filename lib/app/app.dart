import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/events/auth_events.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import 'bootstrap/dependencies.dart';
import 'localization/locale_manager.dart';
import 'router/app_router.dart';
import '../design_system/design_system.dart';
import 'theme/theme.dart';
import 'theme/theme_mode_manager.dart';

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

    // What a member may do lives in their session. When the server says their
    // access changed, the session is read again, so the shell and every screen
    // see the new permissions without a restart.
    ref
        .read(socketManagerProvider)
        .accessChanges
        .listen((_) => unawaited(coordinator.reloadSession()));

    coordinator.events.listen((event) async {
      switch (event) {
        case SignedIn(:final session, :final wasRestored):
          if (!wasRestored) {
            // First sign-in, including Google: follow the locale the server
            // stored, unless the member already chose a language on this
            // device.
            await ref
                .read(localeProvider.notifier)
                .adoptFromSession(session.user.locale);
          }

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
    final theme = ref.watch(themeSelectionProvider);

    return MaterialApp.router(
      title: 'TajeerAi',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(preset: theme.preset),
      darkTheme: AppTheme.dark(preset: theme.preset),
      // Both palettes of every preset are complete, so following the system is
      // a real default rather than a placeholder. The member can override it.
      themeMode: theme.mode.mode,
      // One ceiling for the whole app. Past 2x a conversation list stops being
      // a list -- two rows fill the screen and the rail no longer answers the
      // question it exists for. Controls that cannot grow carry a tighter
      // clamp of their own; dense rows carry none and simply get taller.
      builder: (BuildContext context, Widget? child) =>
          MediaQuery.withClampedTextScaling(
            minScaleFactor: 1,
            maxScaleFactor: TajeerTypography.maxTextScale,
            child: child!,
          ),
      locale: locale.locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppDesignSystemLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
