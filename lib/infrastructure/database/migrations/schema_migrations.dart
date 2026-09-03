import 'package:drift/drift.dart';

/// Schema versioning and indexes.
///
/// Kept out of `AppDatabase` so the migration history stays readable as it
/// grows: a database class that also carries every upgrade step becomes the
/// longest file in the project by version 5.
///
/// Rules for adding a version:
/// 1. Bump [version].
/// 2. Add an `if (from <= n)` block to [strategy]'s `onUpgrade`. Never edit an
///    existing block -- a shipped migration has already run on real devices.
/// 3. Add a migration test.
abstract final class SchemaMigrations {
  /// v1 -- conversations, messages, session, outbox, sync metadata.
  static const int version = 1;

  static MigrationStrategy strategy(GeneratedDatabase database) {
    return MigrationStrategy(
      onCreate: (Migrator migrator) async {
        await migrator.createAll();
        await _createIndexes(database, migrator);
      },
      onUpgrade: (Migrator migrator, int from, int to) async {
        // No upgrades yet. Each future version appends its own block here.
      },
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
  }
}
