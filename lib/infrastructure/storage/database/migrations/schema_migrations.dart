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
  /// v7 -- `conversations.window_expires_at` and
  ///       `is_within_customer_service_window`, so the composer knows whether
  ///       WhatsApp will accept a free-form message before one is typed.
  /// v8 -- the conversation's customer panel: `customers.metadata` for the
  ///       WhatsApp username and id, `customer_notes.follow_up_at` and
  ///       `follow_up_done_at` so open follow-ups can be listed, and
  ///       `customer_orders` for a contact's recent orders.
  /// v9 -- `conversation_notes`: a thread's own record - internal notes, the
  ///       log of what happened to it, the assistant's summaries - drawn
  ///       between the bubbles the way the web's inbox draws them.
  /// v10 -- `customers.blocked_at`, `block_reason` and `aliases`: whether the
  ///       workspace blocked the contact, and the other names a merged
  ///       duplicate brought with it.
  static const int version = 10;

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
        from6To7: (Migrator migrator, Schema7 schema) async {
          /*
            Both null on an upgraded device, which is the honest answer until
            the next sync: this device has never been told what the window is.
            Null means "unreported" and blocks nothing, so an upgrade cannot
            disable a composer that was working a minute ago - the server still
            refuses a send that is genuinely outside the window.
          */
          await migrator.addColumn(
            schema.conversations,
            schema.conversations.windowExpiresAt,
          );
          await migrator.addColumn(
            schema.conversations,
            schema.conversations.isWithinCustomerServiceWindow,
          );
        },
        from7To8: (Migrator migrator, Schema8 schema) async {
          /*
            Every new column has a default or is nullable, so an upgraded
            device reads as "not yet told" until its next sync: an empty
            metadata object, no follow-up on any entry, no orders. The next
            refresh of a contact fills all three from the server.
          */
          await migrator.addColumn(schema.customers, schema.customers.metadata);
          await migrator.addColumn(
            schema.customerNotes,
            schema.customerNotes.followUpAt,
          );
          await migrator.addColumn(
            schema.customerNotes,
            schema.customerNotes.followUpDoneAt,
          );
          await migrator.createTable(schema.customerOrders);
          await _createOrderIndexes(database);
        },
        from8To9: (Migrator migrator, Schema9 schema) async {
          await migrator.createTable(schema.conversationNotes);
          await _createConversationNoteIndexes(database);
        },
        from9To10: (Migrator migrator, Schema10 schema) async {
          /*
            Nullable or defaulted, so an upgraded device reads every contact
            as "not blocked, no other names" until the next sync or refresh
            says otherwise. Not blocked is the safe misreading: the server is
            what refuses a send to a blocked contact, not this column.
          */
          await migrator.addColumn(
            schema.customers,
            schema.customers.blockedAt,
          );
          await migrator.addColumn(
            schema.customers,
            schema.customers.blockReason,
          );
          await migrator.addColumn(schema.customers, schema.customers.aliases);
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
    await _createOrderIndexes(database);
    await _createConversationNoteIndexes(database);
  }

  /// The record index, shared by `onCreate` and the v9 step: one thread's
  /// entries in time order, which is the only way the table is read.
  static Future<void> _createConversationNoteIndexes(
    GeneratedDatabase database,
  ) async {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversation_notes_conversation_created '
      'ON conversation_notes (conversation_id, created_at)',
    );
  }

  /// The order index, shared by `onCreate` and the v8 step: one contact's
  /// orders, newest first, which is the only way the table is read.
  static Future<void> _createOrderIndexes(GeneratedDatabase database) async {
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_customer_orders_customer_placed '
      'ON customer_orders (customer_id, placed_at DESC)',
    );
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
