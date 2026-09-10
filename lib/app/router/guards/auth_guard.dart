import '../../../features/auth/application/state/auth_state.dart';
import '../routes.dart';

/// Decides where an unresolved navigation should land.
///
/// Pure: it takes the current auth state and the location being navigated to,
/// and returns a redirect or null. No Riverpod, no `BuildContext`, no router
/// -- which is what makes every branch below testable as a plain function
/// call, and why the redirect logic is here rather than inline in a closure.
abstract final class AuthGuard {
  /// Routes reachable without a session.
  ///
  /// The design system's showcase is here unconditionally, and that is safe
  /// rather than lax: the *route* only exists under `kDebugMode`, so in a
  /// release build there is nothing at the other end of this entry. Keeping it
  /// unconditional is what lets this class stay a pure function of
  /// (state, location) — no build-mode branching, no Flutter import.
  static const Set<String> publicRoutes = <String>{
    AppRoutes.login,
    AppRoutes.designSystem,
  };

  /// The redirect target, or null to allow the navigation.
  ///
  /// The three rules, in order:
  ///
  /// 1. While the session is still unknown, hold on the splash route. Deciding
  ///    anything else here would flash the login screen at a signed-in user.
  /// 2. No session and heading somewhere private -> login.
  /// 3. A session and heading to login or splash -> the Inbox.
  static String? redirect({
    required AuthState state,
    required String location,
  }) {
    final isPublic = publicRoutes.contains(location);
    final isSplash = location == AppRoutes.splash;

    if (!state.isResolved) {
      return isSplash ? null : AppRoutes.splash;
    }

    if (!state.isAuthenticated) {
      return isPublic ? null : AppRoutes.login;
    }

    // Signed in: the splash and login screens have nothing left to do.
    if (isPublic || isSplash) return AppRoutes.conversations;

    return null;
  }
}
