import '../../../features/auth/application/state/auth_state.dart';
import '../../../features/auth/domain/entities/user.dart';
import '../../shell/shell_destination.dart';
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
  /// The four rules, in order:
  ///
  /// 1. While the session is still unknown, hold on the splash route. Deciding
  ///    anything else here would flash the login screen at a signed-in user.
  /// 2. No session and heading somewhere private -> login.
  /// 3. A session and heading to login or splash -> the member's first
  ///    destination.
  /// 4. A session and heading into a destination the member may not open ->
  ///    the same. The router asks again whenever the session changes, so a
  ///    permission withdrawn while its screen is open moves the member off it.
  static String? redirect({
    required AuthState state,
    required String location,
  }) {
    final isPublic = publicRoutes.contains(location);
    final isSplash = location == AppRoutes.splash;

    if (!state.isResolved) {
      return isSplash ? null : AppRoutes.splash;
    }

    final Session? session = state.session;

    if (!state.isAuthenticated || session == null) {
      return isPublic ? null : AppRoutes.login;
    }

    final ShellDestination home = ShellDestination.homeFor(session.user);

    // Signed in: the splash and login screens have nothing left to do.
    if (isPublic || isSplash) return home.path;

    final ShellDestination? destination = ShellDestination.containing(location);

    // Never away from home itself: when nothing is open to the member, home
    // is the one place left, and sending them there again would loop.
    if (destination != null &&
        destination != home &&
        !destination.isOpenTo(session.user)) {
      return home.path;
    }

    return null;
  }

  /// Whether [next] can change where [redirect] sends anyone.
  ///
  /// Who is signed in and what they may open, not only whether anyone is: a
  /// session re-read with a permission withdrawn has to move the member off
  /// that screen, though they never stopped being signed in.
  static bool affectsRouting(AuthState? previous, AuthState next) =>
      previous?.status != next.status || previous?.session != next.session;
}
