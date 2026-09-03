import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/auth/data/local/auth_tables.dart';
import '../../features/conversations/data/local/conversation_dao.dart';
import '../../features/conversations/data/local/conversation_tables.dart';
import 'daos/outbox_dao.dart';
import 'daos/sync_dao.dart';
import 'migrations/schema_migrations.dart';
import 'tables/outbox_table.dart';
import 'tables/sync_state_table.dart';

part 'app_database.g.dart';

/// The local database -- the application's primary read source.
///
/// ## Why Drift
///
/// The architecture asks for reactive queries over relational data with
/// migrations and indexes, and Drift is the only mature Flutter option that
/// gives all of it at once. Specifically:
///
/// - **Reactive queries.** `watch()` re-emits when a write touches a table the
///   query reads. That is the whole offline-first read path: a socket event
///   writes a row and the thread on screen updates, with no manual
///   invalidation and no second copy of the list in a controller.
/// - **Relational.** Conversations and messages are a parent/child relation
///   queried by foreign key and sorted by time; a document store would make
///   the rail's ordering a client-side sort over everything.
/// - **Migrations and indexes** are first-class, and the schema will move.
/// - **Type-safe SQL** generated at build time, so a renamed column fails the
///   build rather than at runtime on a user's phone.
///
/// Hive and Isar were the alternatives. Hive has no reactive relational
/// queries; Isar's maintenance status makes it a poor foundation for a
/// long-lived app.
///
/// ## What it does not do
///
/// No business rules. DAOs read and write rows; deciding whether a message may
/// be sent belongs to a domain service. See `ARCHITECTURE.md`.
@DriftDatabase(
  tables: <Type>[
    Conversations,
    Messages,
    SessionUsers,
    OutboxEntries,
    SyncStates,
    ProcessedEvents,
  ],
  daos: <Type>[OutboxDao, SyncDao, ConversationDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tajeerai'));

  /// An in-memory database for tests.
  ///
  /// Every persistence test in this project runs against a real SQLite engine
  /// rather than a mock, because the behaviour under test -- reactive
  /// emission, upsert semantics, ordering, index use -- is the engine's, and a
  /// mock would only assert that the code calls the methods it calls.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => SchemaMigrations.version;

  @override
  MigrationStrategy get migration => SchemaMigrations.strategy(this);
}
