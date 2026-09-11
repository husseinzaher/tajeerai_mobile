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
  /// `SessionUserDto.permissions`.
  final Set<String> permissions;

  /// Whether this user holds [permission].
  ///
  /// Platform admins hold everything, which matches how the backend treats
  /// `isPlatformAdmin` in its own guards. A wildcard grant (`*`) is honoured
  /// the same way the server's rule serialisation expresses it.
  bool can(String permission) {
    if (isPlatformAdmin) return true;

    return permissions.contains(permission) || permissions.contains('*');
  }

  /// Permissions are part of who this user is to the app.
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
      other.permissions.containsAll(permissions);

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
