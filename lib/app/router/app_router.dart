import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/state/auth_state.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/conversations/presentation/screens/conversation_list_screen.dart';
import '../../features/conversations/presentation/screens/conversation_screen.dart';
import '../../design_system/loaders/app_splash.dart';
import '../../design_system/showcase/showcase_app.dart';
import '../shell/authenticated_shell.dart';
import '../shell/shell_destination.dart';
import 'guards/auth_guard.dart';
import 'routes.dart';

/// The application's router.
///
/// go_router because the requirements are guards, nested routes and deep links
/// -- a declarative router that can answer "where should this navigation go"
/// from application state, which an imperative `Navigator` cannot without the
/// state being duplicated into it.
///
/// Routing reacts to authentication through [_AuthRefreshNotifier]: the router
/// re-evaluates its redirect whenever the session changes in a way that can
/// move someone, so signing out anywhere in the app -- including from the
/// socket's `auth.expired` path -- moves the user to the login screen without
/// any screen calling `go()`.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  // The root navigator, so a route can be pushed over the whole shell rather
  // than inside its body.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      return AuthGuard.redirect(
        // `read`, not `watch`: the redirect is re-run by the listenable above,
        // and watching here would rebuild the provider itself on every change.
        state: ref.read(authControllerProvider),
        location: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const AppSplash(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // Debug only. `kDebugMode` is a const, so the release compiler drops the
      // branch and tree-shakes the showcase out entirely -- the import above
      // costs a release build nothing, and must not be "optimised" into a
      // deferred one.
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.designSystem,
          name: AppRouteNames.designSystem,
          builder: (context, state) => const ShowcaseApp(),
        ),
      // The signed-in frame: the navigation drawer, and the bottom bar once
      // there is more than one destination. One branch per destination, each
      // kept alive while another is shown, so coming back to one finds it as
      // it was left -- scrolled, searched, filtered. Screens draw in its body
      // and keep their own toolbars.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AuthenticatedShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final ShellDestination destination in ShellDestination.values)
            StatefulShellBranch(
              routes: _destinationRoutes(destination, rootNavigatorKey),
            ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });

  return router;
});

/// The routes that start at [destination].
///
/// A switch rather than a lookup, so a destination added to
/// [ShellDestination] without its screens does not compile. A detail or a
/// form opens on [rootNavigatorKey]: it covers the shell rather than opening
/// inside it with the drawer and the bottom bar still reachable behind.
List<RouteBase> _destinationRoutes(
  ShellDestination destination,
  GlobalKey<NavigatorState> rootNavigatorKey,
) {
  return switch (destination) {
    ShellDestination.inbox => <RouteBase>[
      GoRoute(
        path: destination.path,
        name: AppRouteNames.conversations,
        builder: (context, state) => const ConversationListScreen(),
        routes: <RouteBase>[
          // Nested, so back returns to the rail.
          // Deep-link ready: the id comes from the path, and the screen reads
          // it from local storage before any network call.
          GoRoute(
            path: AppRoutes.conversationDetail,
            name: AppRouteNames.conversationDetail,
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
          ),
        ],
      ),
    ],
  };
}

/// Bridges Riverpod's auth state to go_router's `refreshListenable`.
///
/// go_router re-evaluates `redirect` when this notifies. Without it the
/// redirect would only run on an explicit navigation, so a session expiring
/// while the user sits on a screen would leave them there, looking at data the
/// server has stopped updating.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(authControllerProvider, (
      previous,
      next,
    ) {
      if (!AuthGuard.affectsRouting(previous, next)) return;

      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
