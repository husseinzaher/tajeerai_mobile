import 'package:drift/drift.dart';

/// The signed-in user, cached for offline start-up.
///
/// One row, keyed by the user's id. Persisted so the app can render its
/// authenticated shell before the network answers -- an offline-first app that
/// shows a sign-in screen because it has not reached the server yet has failed
/// at the first hurdle.
///
/// Holds no credential. Tokens live in the Keychain; see `SecureStorage`.
@DataClassName('SessionUserRow')
class SessionUsers extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text()();
  TextColumn get locale => text()();
  TextColumn get avatarUrl => text().nullable()();

  BoolColumn get isPlatformAdmin =>
      boolean().withDefault(const Constant(false))();

  /// JSON array of permission strings, from `SessionUserDto.permissions`.
  TextColumn get permissions => text().withDefault(const Constant('[]'))();

  /// JSON array of denied permission strings, from `SessionUserDto.denied`.
  ///
  /// Cached with the grants: without it, a member holding `manage:all` less
  /// one capability would be offered that capability on every offline start.
  TextColumn get denied => text().withDefault(const Constant('[]'))();

  TextColumn get tenantId => text().nullable()();
  TextColumn get tenantName => text().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
