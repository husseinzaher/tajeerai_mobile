import '../../features/auth/domain/entities/user.dart';
import '../router/routes.dart';

/// The places the signed-in shell takes a member, in the order it lists them.
///
/// Plain Dart on purpose -- no icon, no label, no widget -- so `AuthGuard` can
/// ask where a member may go without importing Flutter. The shell gives each
/// destination its icon and label and the router gives it its screens, both
/// through a switch over this enum, so a destination added without either
/// does not compile.
///
/// **Only destinations that exist.** One arrives here with its screen, never
/// before: an entry for a screen that is not built is a control that goes
/// nowhere.
enum ShellDestination {
  inbox(AppRoutes.conversations, permission: 'read:Conversation'),

  /// Last, and open to every member: whatever a role withholds, the account
  /// and the way out are always reachable.
  settings(AppRoutes.settings);

  const ShellDestination(this.path, {this.permission});

  /// Where the destination's own stack starts.
  final String path;

  /// What a member needs to be offered it, the same permission the web
  /// dashboard gates the same screen on. Null when every member may.
  final String? permission;

  bool isOpenTo(AuthenticatedUser user) {
    final String? required = permission;

    return required == null || user.can(required);
  }

  /// Whether [location] is this destination or somewhere inside it.
  bool covers(String location) =>
      location == path || location.startsWith('$path/');

  /// The destination [location] is inside, or null for a route outside the
  /// shell.
  static ShellDestination? containing(String location) {
    for (final ShellDestination destination in values) {
      if (destination.covers(location)) return destination;
    }

    return null;
  }

  /// Where [user] lands once signed in: the first destination open to them.
  ///
  /// Settings needs no permission, so there always is one. The fallback is
  /// for a list edited to lose that: the first destination still takes the
  /// member, because sending them nowhere leaves the router with no route.
  static ShellDestination homeFor(AuthenticatedUser user) {
    for (final ShellDestination destination in values) {
      if (destination.isOpenTo(user)) return destination;
    }

    return values.first;
  }
}
