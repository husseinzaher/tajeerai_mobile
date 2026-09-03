import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/conversations/data/local/conversation_tables.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';

import '../../support/fixed_clock.dart';
import '../../support/test_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  group('schema', () {
    test('creates every table at the current schema version', () async {
      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();

      final names = tables.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>[
          'conversations',
          'messages',
          'session_users',
          'outbox_entries',
          'sync_states',
          'processed_events',
        ]),
      );
    });

    test('creates the indexes the read paths depend on', () async {
      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();

      final names = indexes.map((row) => row.read<String>('name')).toSet();

      // Each of these backs a query that runs on a screen. Without them the
      // rail degrades to a full scan once a workspace has real volume.
      expect(
        names,
        containsAll(<String>[
          'idx_conversations_last_message_at',
          'idx_messages_conversation_created',
          'idx_messages_client_message_id',
          'idx_outbox_status_next_attempt',
        ]),
      );
    });

    test('enforces foreign keys', () async {
      final result = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();

      expect(result.data.values.first, 1);
    });
  });

  group('conversations table', () {
    test('inserts and reads back a row', () async {
      await database
          .into(database.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'c1',
              state: ConversationStateRow.open,
              createdAt: testEpoch,
            ),
          );

      final row = await database.select(database.conversations).getSingle();

      expect(row.id, 'c1');
      expect(row.unreadCount, 0);
      expect(row.isArchived, isFalse);
    });

    test('upserts on conflicting id rather than duplicating', () async {
      Future<void> write(int unread) => database
          .into(database.conversations)
          .insertOnConflictUpdate(
            ConversationsCompanion.insert(
              id: 'c1',
              state: ConversationStateRow.open,
              createdAt: testEpoch,
              unreadCount: Value<int>(unread),
            ),
          );

      await write(1);
      await write(5);

      final rows = await database.select(database.conversations).get();

      expect(rows, hasLength(1));
      expect(rows.single.unreadCount, 5);
    });
  });

  group('reactive queries', () {
    test('re-emit when a write touches the watched table', () async {
      final emissions = <int>[];

      final subscription = database
          .select(database.conversations)
          .watch()
          .listen((rows) => emissions.add(rows.length));

      // The first emission is the empty table.
      await pumpEventQueue();

      await database
          .into(database.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'c1',
              state: ConversationStateRow.open,
              createdAt: testEpoch,
            ),
          );

      await pumpEventQueue();

      await subscription.cancel();

      // This is the mechanism the whole offline-first read path rests on: a
      // write anywhere reaches the screen without an invalidation call.
      expect(emissions, containsAllInOrder(<int>[0, 1]));
    });
  });

  group('transactions', () {
    test('roll back entirely when the body throws', () async {
      await expectLater(
        database.transaction(() async {
          await database
              .into(database.conversations)
              .insert(
                ConversationsCompanion.insert(
                  id: 'c1',
                  state: ConversationStateRow.open,
                  createdAt: testEpoch,
                ),
              );

          throw StateError('interrupted');
        }),
        throwsA(isA<StateError>()),
      );

      final rows = await database.select(database.conversations).get();

      // The message-plus-outbox write depends on this: a half-applied
      // transaction would leave a message that never sends.
      expect(rows, isEmpty);
    });
  });
}
