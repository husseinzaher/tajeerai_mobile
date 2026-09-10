import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/state/auth_state.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/conversations/presentation/screens/conversation_list_screen.dart';
import '../../features/conversations/presentation/screens/conversation_screen.dart';
import '../../design_system/loaders/app_splash.dart';
import '../../design_system/showcase/showcase_app.dart';
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
/// re-evaluates its redirect whenever [AuthState] changes, so signing out
/// anywhere in the app -- including from the socket's `auth.expired` path --
/// moves the user to the login screen without any screen calling `go()`.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  final router = GoRouter(
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
      GoRoute(
        path: AppRoutes.conversations,
        name: AppRouteNames.conversations,
        builder: (context, state) => const ConversationListScreen(),
        routes: <RouteBase>[
          // Nested, so the thread pushes over the rail and back returns there.
          // Deep-link ready: the id comes from the path, and the screen reads
          // it from local storage before any network call.
          GoRoute(
            path: AppRoutes.conversationDetail,
            name: AppRouteNames.conversationDetail,
            builder: (context, state) => ConversationScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
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
      if (previous?.status == next.status) return;

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
