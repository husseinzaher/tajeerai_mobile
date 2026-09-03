import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../infrastructure/database/app_database.dart';
import '../../../../infrastructure/storage/secure_storage.dart';
import '../../domain/entities/user.dart';

/// Local persistence for the session.
///
/// Split deliberately across two stores, by sensitivity:
///
/// - the **user and workspace** go in the database, because they are ordinary
///   data the app has to render offline at start-up;
/// - the **tokens** go in the Keychain, because they are credentials and the
///   database is not encrypted.
///
/// Putting the token in the row next to the name would be the easy version and
/// would put a bearer credential in a file a backup can carry off the device.
class AuthLocalDataSource {
  const AuthLocalDataSource({
    required AppDatabase database,
    required SecureStorage secureStorage,
  }) : _database = database,
       _secureStorage = secureStorage;

  final AppDatabase _database;
  final SecureStorage _secureStorage;

  /// Replaces the cached session.
  ///
  /// Only ever one row: signing in as a different user must not leave the
  /// previous one readable, so the table is cleared first inside the same
  /// transaction.
  Future<void> saveSession(Session session, {required DateTime now}) {
    return _database.transaction(() async {
      await _database.delete(_database.sessionUsers).go();

      await _database
          .into(_database.sessionUsers)
          .insert(
            SessionUsersCompanion.insert(
              id: session.user.id,
              name: session.user.name,
              email: session.user.email,
              phone: Value<String?>(session.user.phone),
              role: session.user.role,
              locale: session.user.locale,
              avatarUrl: Value<String?>(session.user.avatarUrl),
              isPlatformAdmin: Value<bool>(session.user.isPlatformAdmin),
              permissions: Value<String>(
                jsonEncode(session.user.permissions.toList()),
              ),
              tenantId: Value<String?>(session.workspace?.id),
              tenantName: Value<String?>(session.workspace?.name),
              updatedAt: now,
            ),
          );
    });
  }

  /// The cached session, or null when nobody has signed in on this device.
  Future<Session?> readSession() async {
    final row = await _database
        .select(_database.sessionUsers)
        .getSingleOrNull();

    if (row == null) return null;

    return Session(
      user: AuthenticatedUser(
        id: row.id,
        name: row.name,
        email: row.email,
        phone: row.phone,
        role: row.role,
        locale: row.locale,
        avatarUrl: row.avatarUrl,
        isPlatformAdmin: row.isPlatformAdmin,
        permissions: _decodePermissions(row.permissions),
      ),
      workspace: row.tenantId == null
          ? null
          : Workspace(
              id: row.tenantId!,
              name: row.tenantName ?? '',
              slug: '',
              locale: row.locale,
            ),
    );
  }

  /// Emits whenever the cached session changes, so the router can react to a
  /// sign-out that happened anywhere in the app.
  Stream<Session?> watchSession() {
    return _database.select(_database.sessionUsers).watchSingleOrNull().map((
      row,
    ) {
      if (row == null) return null;

      return Session(
        user: AuthenticatedUser(
          id: row.id,
          name: row.name,
          email: row.email,
          phone: row.phone,
          role: row.role,
          locale: row.locale,
          avatarUrl: row.avatarUrl,
          isPlatformAdmin: row.isPlatformAdmin,
          permissions: _decodePermissions(row.permissions),
        ),
        workspace: row.tenantId == null
            ? null
            : Workspace(
                id: row.tenantId!,
                name: row.tenantName ?? '',
                slug: '',
                locale: row.locale,
              ),
      );
    });
  }

  Future<String?> readAccessToken() =>
      _secureStorage.read(SecureStorage.accessTokenKey);

  /// Wipes everything tied to the session.
  ///
  /// Clears the *business* tables too. Conversations and messages belong to
  /// the workspace that was signed in; leaving them for the next user to read
  /// would be a data leak, not a cache hit.
  Future<void> clear() async {
    await _database.transaction(() async {
      await _database.delete(_database.sessionUsers).go();
      await _database.delete(_database.messages).go();
      await _database.delete(_database.conversations).go();
      await _database.delete(_database.outboxEntries).go();
      await _database.syncDao.clear();
    });

    await _secureStorage.clear();
  }

  static Set<String> _decodePermissions(String raw) {
    if (raw.isEmpty) return const <String>{};

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) return const <String>{};

      return decoded.map((entry) => entry.toString()).toSet();
    } on FormatException {
      // A corrupted cache must not stop the user signing in; they simply come
      // back with no cached permissions until the next server response.
      return const <String>{};
    }
  }
}
