import 'package:drift/drift.dart';

import '../app_database.steps.dart';

/// Schema versioning and indexes.
///
/// Kept out of `AppDatabase` so the migration history stays readable as it
/// grows: a database class that also carries every upgrade step becomes the
/// longest file in the project by version 5.
///
/// Rules for adding a version:
/// 1. Change the tables, and bump [version].
/// 2. Run `make migrations`. It snapshots the new schema into
///    `drift_schemas/` and regenerates `app_database.steps.dart`, which gives
///    `stepByStep` a required `fromNToM` for the new step, along with the
///    schemas the migration tests open.
/// 3. Write that step in [strategy]. A step works against its own version's
///    snapshot, so a later table change cannot break it. Never edit a step
///    that has shipped -- it has already run on real devices.
/// 4. When the step moves or reshapes existing rows, add a data test to
///    `test/drift/app_database/migration_test.dart`.
abstract final class SchemaMigrations {
  /// v1 -- conversations, messages, session, outbox, sync metadata.
  /// v2 -- `sync_states.page_cursor`, for the paged HTTP syncs.
  /// v3 -- `session_users.denied`, so a withdrawn capability outlives a
  ///       restart.
  /// v4 -- `customers` and `customer_notes`, with the phone lookup indexes a
  ///       caller card answers from.
  /// v5 -- `caller_identity_cache` for fast CallScreeningService lookups.
  /// v6 -- `conversations.failed_message_count`, so the rail can say which
  ///       thread has a send that did not go out.
  static const int version = 6;

  static MigrationStrategy strategy(GeneratedDatabase database) {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
        await _createIndexes(database, migrator);
      },
      onUpgrade: stepByStep(
        from1To2: (Migrator migrator, Schema2 schema) async {
          await migrator.addColumn(
            schema.syncStates,
            schema.syncStates.pageCursor,
          );
        },
        from2To3: (Migrator migrator, Schema3 schema) async {
          // The column's default fills the cached row: nothing withheld until
          // the next session read says otherwise.
          await migrator.addColumn(
            schema.sessionUsers,
            schema.sessionUsers.denied,
          );
        },
        from3To4: (Migrator migrator, Schema4 schema) async {
          await migrator.createTable(schema.customers);
          await migrator.createTable(schema.customerNotes);

          // New tables need their indexes here as well as in `onCreate`, or
          // only fresh installs get them -- and the phone lookup is the one
          // read in this app with a deadline attached to it.
          await _createCustomerIndexes(database);
        },
        from4To5: (Migrator migrator, Schema5 schema) async {
          await migrator.createTable(schema.callerIdentityCaches);
        },
        from5To6: (Migrator migrator, Schema6 schema) async {
          // The column's default of zero is the right answer for an upgraded
          // device until the next sync: the count is the server's, and every
          // conversation the rail reloads brings its own.
          await migrator.addColumn(
            schema.conversations,
            schema.conversations.failedMessageCount,
          );
        },
      ),
      beforeOpen: (OpeningDetails details) async {
        // Drift does not enforce foreign keys unless asked, and the messages
        // -> conversations relation is only useful if it is actually enforced.
        await database.customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// The indexes the app's read patterns need.
  ///
  /// Written out rather than left to SQLite: every one of these backs a query
  /// that runs on a screen, and without them the rail degrades to a full scan
  /// once a workspace has a few thousand threads.
  ///
  /// Only a fresh install runs this. A version that adds an index creates it
  /// in its own step as well, or upgraded devices never get it.
  static Future<void> _createIndexes(
    GeneratedDatabase database,
    Migrator migrator,
  ) async {
    const statements = <String>[
      // The rail: newest activity first, archived excluded.
      'CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at '
          'ON conversations (is_archived, last_message_at DESC)',
      // The thread: one conversation's messages in time order, which is also
      // what paginating backwards from a cursor walks.
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created '
          'ON messages (conversation_id, created_at DESC)',
      // Reconciling an acknowledgement back to its optimistic row.
      'CREATE INDEX IF NOT EXISTS idx_messages_client_message_id '
          'ON messages (client_message_id)',
      // Messages still in flight, for the retry affordance.
      'CREATE INDEX IF NOT EXISTS idx_messages_state '
          'ON messages (state)',
      // The outbox drain: due work, oldest first.
      'CREATE INDEX IF NOT EXISTS idx_outbox_status_next_attempt '
          'ON outbox_entries (status, next_attempt_at)',
      // Pruning applied events by age.
      'CREATE INDEX IF NOT EXISTS idx_processed_events_processed_at '
          'ON processed_events (processed_at)',
    ];

    for (final statement in statements) {
      await database.customStatement(statement);
    }

    await _createCustomerIndexes(database);
  }

  /// The contact indexes, shared by `onCreate` and the v4 step.
  ///
  /// Written once rather than twice: an index a fresh install has and an
  /// upgraded device does not is the kind of difference that shows up as "the
  /// caller card is slow on my phone only".
  static Future<void> _createCustomerIndexes(GeneratedDatabase database) async {
    const statements = <String>[
      // The caller card: a ringing number, compared suffix to suffix. An
      // equality test rather than a trailing `LIKE`, because this one has a
      // deadline -- the phone is ringing while it runs.
      'CREATE INDEX IF NOT EXISTS idx_customers_phone_suffix '
          'ON customers (phone_suffix)',
      // Typing a number into the contact search.
      'CREATE INDEX IF NOT EXISTS idx_customers_phone_digits '
          'ON customers (phone_digits)',
      // The list's own order, and the reconciliation sweep that reads
      // `seen_at`.
      'CREATE INDEX IF NOT EXISTS idx_customers_updated_at '
          'ON customers (updated_at DESC)',
      'CREATE INDEX IF NOT EXISTS idx_customers_seen_at '
          'ON customers (seen_at)',
      // One contact's entries, newest first -- what the detail screen reads.
      'CREATE INDEX IF NOT EXISTS idx_customer_notes_customer_created '
          'ON customer_notes (customer_id, created_at DESC)',
    ];

    for (final statement in statements) {
      await database.customStatement(statement);
    }
  }
}
