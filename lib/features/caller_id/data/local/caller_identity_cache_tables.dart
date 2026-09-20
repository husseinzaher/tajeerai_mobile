import 'package:drift/drift.dart';

/// Cached caller lookup results for fast CallScreeningService reads.
class CallerIdentityCaches extends Table {
  TextColumn get normalizedPhone => text()();

  TextColumn get displayName => text().nullable()();

  TextColumn get businessName => text().nullable()();

  TextColumn get avatarUrl => text().nullable()();

  TextColumn get spamStatus => text().withDefault(const Constant('unknown'))();

  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();

  TextColumn get source => text().withDefault(const Constant('unknown'))();

  TextColumn get customerId => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime()();

  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{normalizedPhone};
}
