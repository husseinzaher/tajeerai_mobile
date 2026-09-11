/// The signed-in user.
///
/// Mirrors the backend's `SessionUserDto`, minus anything the client has no
/// use for. Immutable, and free of any framework type -- this is the shape the
/// rest of the app reasons about, not a row and not a JSON map.
final class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.locale,
    this.phone,
    this.avatarUrl,
    this.isPlatformAdmin = false,
    this.permissions = const <String>{},
    this.denied = const <String>{},
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;

  /// BCP-47 tag from the server. The app follows it on first sign-in so an
  /// Arabic-speaking operator does not have to set the language twice.
  final String locale;

  final String? avatarUrl;
  final bool isPlatformAdmin;

  /// Capabilities with any withdrawn one already removed, from
  /// `SessionUserDto.permissions`, written `action:Subject`.
  final Set<String> permissions;

  /// Capabilities a direct denial took away, from `SessionUserDto.denied`.
  ///
  /// Sent apart from [permissions] because that list cannot express one: a
  /// member holding `manage:all` is granted everything it does not name, so
  /// an exception has to be named on its own.
  final Set<String> denied;

  /// Whether this user holds [permission], written `action:Subject`.
  ///
  /// The reading the web dashboard gives the same session. A denial is
  /// checked first, because reading a wildcard first would say yes to the one
  /// thing the backend is about to refuse. Then both of CASL's wildcards
  /// count -- `manage` is any action and `all` any subject -- since that is
  /// how roles are written: an owner holds `manage:all`.
  ///
  /// Being a platform admin adds nothing: the backend's guard asks the same
  /// rules for one, and the session already carries what they resolve to. It
  /// stays a hint about what to show; the guard makes the decision.
  bool can(String permission) {
    if (denied.contains(permission)) return false;

    final int colon = permission.indexOf(':');
    final String action = colon < 0
        ? permission
        : permission.substring(0, colon);
    final String subject = colon < 0 ? '' : permission.substring(colon + 1);

    return permissions.contains(permission) ||
        permissions.contains('$action:all') ||
        permissions.contains('manage:$subject') ||
        permissions.contains('manage:all');
  }

  /// Permissions and denials are part of who this user is to the app.
  ///
  /// They used to be left out, so a session re-read with a permission granted
  /// or withdrawn compared equal to the old one, and the change never reached
  /// a screen.
  @override
  bool operator ==(Object other) =>
      other is AuthenticatedUser &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.role == role &&
      other.locale == locale &&
      other.avatarUrl == avatarUrl &&
      other.isPlatformAdmin == isPlatformAdmin &&
      other.permissions.length == permissions.length &&
      other.permissions.containsAll(permissions) &&
      other.denied.length == denied.length &&
      other.denied.containsAll(denied);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    phone,
    role,
    locale,
    avatarUrl,
    isPlatformAdmin,
    Object.hashAllUnordered(permissions),
    Object.hashAllUnordered(denied),
  );

  @override
  String toString() => 'AuthenticatedUser($id)';
}

/// The workspace the session belongs to.
///
/// Nullable throughout the app: a platform admin signs in without one, which
/// the backend models as `SessionDto.tenant: null`.
final class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.locale,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String locale;
  final String? logoUrl;

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.locale == locale &&
      other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(id, name, slug, locale, logoUrl);
}

/// A user plus the workspace they are signed into.
final class Session {
  const Session({required this.user, this.workspace});

  final AuthenticatedUser user;
  final Workspace? workspace;

  /// A session with no workspace can read the back office but none of the
  /// workspace features -- the socket joins no tenant room for it, so the
  /// Inbox would be permanently empty.
  bool get hasWorkspace => workspace != null;

  @override
  bool operator ==(Object other) =>
      other is Session && other.user == user && other.workspace == workspace;

  @override
  int get hashCode => Object.hash(user, workspace);
}
