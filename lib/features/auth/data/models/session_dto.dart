import '../../domain/entities/user.dart';

/// Decodes the backend's `SessionDto`.
///
/// Hand-written rather than generated: it is one shape, and it has to be
/// forgiving in a way generated code is not. A field the server adds must not
/// break sign-in, and a missing optional must not throw -- an app that cannot
/// log in because the API grew a column is worse than one that ignores it.
abstract final class SessionDto {
  /// Maps `{user, tenant}` onto the domain [Session].
  ///
  /// Throws [FormatException] when the payload is not a session at all, which
  /// the repository turns into a failure. Anything merely *missing* falls back.
  static Session decode(Map<String, Object?> json) {
    final user = json['user'];

    if (user is! Map) {
      throw const FormatException('Response carried no user.');
    }

    final tenant = json['tenant'];

    return Session(
      user: _decodeUser(Map<String, Object?>.from(user)),
      workspace: tenant is Map
          ? _decodeWorkspace(Map<String, Object?>.from(tenant))
          : null,
    );
  }

  static AuthenticatedUser _decodeUser(Map<String, Object?> json) {
    final id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('User carried no id.');
    }

    return AuthenticatedUser(
      id: id,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'member',
      locale: json['locale']?.toString() ?? 'ar',
      avatarUrl: _mediaUrl(json['avatar']),
      isPlatformAdmin: json['isPlatformAdmin'] == true,
      permissions: _stringSet(json['permissions']),
    );
  }

  static Workspace _decodeWorkspace(Map<String, Object?> json) {
    return Workspace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      locale: json['locale']?.toString() ?? 'ar',
      logoUrl: _mediaUrl(json['logo']),
    );
  }

  /// Pulls the URL out of the backend's `MediaResourceDto`, which is an object
  /// rather than a bare string.
  static String? _mediaUrl(Object? raw) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is! Map) return null;

    final url = raw['url'] ?? raw['path'];

    return url?.toString();
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! List) return const <String>{};

    return raw.map((entry) => entry.toString()).toSet();
  }
}
