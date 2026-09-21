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

  /// Subtrees anyone may open, signed in or not.
  ///
  /// Separate from [publicRoutes] because the two answer different questions.
  /// A route in [publicRoutes] is one a *guest* may open and a member has no
  /// use for - signing in is pointless once you have - so a member is sent
  /// home from it. A public subtree is content: the blog reads the same for
  /// both, and bouncing a signed-in member off an article they tapped would be
  /// absurd.
  ///
  /// A prefix rather than an exact path, because an article carries its slug.
  /// The exact-set test this sits beside cannot express `/blog/:slug` at all,
  /// which is why adding one line to that set was not enough.
  static const Set<String> publicPrefixes = <String>{AppRoutes.blog};

  /// The query parameter carrying where a guest was going before login.
  static const String intendedParameter = 'from';

  /// Whether anyone may open [location] without a session.
  static bool isPublic(String location) =>
      publicRoutes.contains(location) || isUnderPublicPrefix(location);

  /// Whether [location] is the root of a public subtree, or inside one.
  static bool isUnderPublicPrefix(String location) => publicPrefixes.any(
    (prefix) => location == prefix || location.startsWith('$prefix/'),
  );

  /// Where to send someone after they sign in, when they were going somewhere.
  ///
  /// Refuses anything that is not a plain in-app path. A value arriving as
  /// `//evil.example` or `https://…` would be a redirect this app performs on
  /// a stranger's behalf, and the fact that it can only be set by this app
  /// today is not a reason to let it be set by anything tomorrow.
  static String? intendedDestination(Map<String, String> queryParameters) {
    final String? intended = queryParameters[intendedParameter];

    if (intended == null || intended.isEmpty) return null;
    if (!intended.startsWith('/') || intended.startsWith('//')) return null;
    if (intended == AppRoutes.login) return null;

    return intended;
  }

  /// The login route, remembering where the caller was trying to go.
  static String loginWithIntent(String location) =>
      '${AppRoutes.login}?$intendedParameter=${Uri.encodeQueryComponent(location)}';

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
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    final bool reachableByGuest = isPublic(location);
    final isSplash = location == AppRoutes.splash;

    if (!state.isResolved) {
      return isSplash ? null : AppRoutes.splash;
    }

    final Session? session = state.session;

    if (!state.isAuthenticated || session == null) {
      /*
        Carrying where they were going, so signing in returns them to it. A
        guest who follows a shared link to an article, then taps something that
        needs an account, should land back on that article - not on an inbox
        they have never seen, wondering what happened to the link.
      */
      return reachableByGuest ? null : loginWithIntent(location);
    }

    final ShellDestination home = ShellDestination.homeFor(session.user);

    /*
      Signed in: the splash and login screens have nothing left to do, and
      login may be holding the destination that sent them there.

      `publicRoutes` rather than `reachableByGuest`, so a public *subtree* is
      not bounced: the blog is for members too.
    */
    if (publicRoutes.contains(location) || isSplash) {
      return intendedDestination(queryParameters) ?? home.path;
    }

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
