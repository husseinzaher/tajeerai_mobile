import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/data/local/conversation_tables.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

ConversationsCompanion _conversation({
  String id = 'c1',
  bool isArchived = false,
  bool isPinned = false,
  DateTime? lastMessageAt,
  String? customerName,
  int unreadCount = 0,
}) {
  return ConversationsCompanion.insert(
    id: id,
    state: ConversationStateRow.open,
    createdAt: testEpoch,
    isArchived: Value<bool>(isArchived),
    isPinned: Value<bool>(isPinned),
    unreadCount: Value<int>(unreadCount),
    customerName: Value<String?>(customerName),
    lastMessageAt: Value<DateTime?>(lastMessageAt),
  );
}

MessagesCompanion _message({
  String id = 'm1',
  String conversationId = 'c1',
  String? clientMessageId,
  DateTime? createdAt,
  MessageStateRow state = MessageStateRow.sent,
  String body = 'hello',
}) {
  return MessagesCompanion.insert(
    id: id,
    conversationId: conversationId,
    clientMessageId: Value<String?>(clientMessageId),
    direction: MessageDirectionRow.outbound,
    state: state,
    body: Value<String?>(body),
    createdAt: createdAt ?? testEpoch,
  );
}

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  group('the ordering guard', () {
    test('accepts a newer event', () async {
      await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 1),
        eventAt: testEpoch,
      );

      final written = await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 5),
        eventAt: testEpoch.add(const Duration(minutes: 1)),
      );

      expect(written, isTrue);
      expect(
        (await database.conversationDao.findConversation('c1'))!.unreadCount,
        5,
      );
    });

    test('refuses an event older than what the row already holds', () async {
      await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 5),
        eventAt: testEpoch.add(const Duration(minutes: 5)),
      );

      final written = await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 1),
        eventAt: testEpoch,
      );

      // A late broadcast must never undo newer state. The backend stamps
      // occurredAt on every event precisely so a client can make this check.
      expect(written, isFalse);
      expect(
        (await database.conversationDao.findConversation('c1'))!.unreadCount,
        5,
      );
    });

    test('applies an unstamped write unguarded', () async {
      await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 5),
        eventAt: testEpoch.add(const Duration(minutes: 5)),
      );

      // A local write is not a server event and carries no stamp; it must not
      // be blocked by one.
      final written = await database.conversationDao.upsertConversation(
        _conversation(unreadCount: 2),
      );

      expect(written, isTrue);
      expect(
        (await database.conversationDao.findConversation('c1'))!.unreadCount,
        2,
      );
    });

    test('guards messages the same way', () async {
      await database.conversationDao.upsertMessage(
        _message(state: MessageStateRow.read),
        eventAt: testEpoch.add(const Duration(minutes: 5)),
      );

      final written = await database.conversationDao.upsertMessage(
        _message(state: MessageStateRow.delivered),
        eventAt: testEpoch,
      );

      expect(written, isFalse);
      expect(
        (await database.conversationDao.findMessage('m1'))!.state,
        MessageStateRow.read,
      );
    });
  });

  group('rail query', () {
    test('excludes archived conversations by default', () async {
      await database.conversationDao.upsertConversation(_conversation(id: 'a'));
      await database.conversationDao.upsertConversation(
        _conversation(id: 'b', isArchived: true),
      );

      final rows = await database.conversationDao.watchConversations().first;

      expect(rows.map((r) => r.id), <String>['a']);
    });

    test('includes archived when asked', () async {
      await database.conversationDao.upsertConversation(_conversation(id: 'a'));
      await database.conversationDao.upsertConversation(
        _conversation(id: 'b', isArchived: true),
      );

      final rows = await database.conversationDao
          .watchConversations(includeArchived: true)
          .first;

      expect(rows, hasLength(2));
    });

    test('filters on the search term', () async {
      await database.conversationDao.upsertConversation(
        _conversation(id: 'a', customerName: 'Ada'),
      );
      await database.conversationDao.upsertConversation(
        _conversation(id: 'b', customerName: 'Grace'),
      );

      final rows = await database.conversationDao
          .watchConversations(searchTerm: 'Ada')
          .first;

      expect(rows.map((r) => r.id), <String>['a']);
    });

    test('returns nothing for a search that matches nothing', () async {
      await database.conversationDao.upsertConversation(
        _conversation(customerName: 'Ada'),
      );

      final rows = await database.conversationDao
          .watchConversations(searchTerm: 'nobody')
          .first;

      expect(rows, isEmpty);
    });

    test('re-emits when a conversation is written', () async {
      final counts = <int>[];

      final subscription = database.conversationDao.watchConversations().listen(
        (rows) => counts.add(rows.length),
      );

      await pumpEventQueue();
      await database.conversationDao.upsertConversation(_conversation());
      await pumpEventQueue();
      await subscription.cancel();

      expect(counts, containsAllInOrder(<int>[0, 1]));
    });
  });

  group('rail freshness', () {
    test('moves the preview and sort key forward on a new message', () async {
      await database.conversationDao.upsertConversation(_conversation());

      final later = testEpoch.add(const Duration(minutes: 5));

      await database.conversationDao.touchWithMessage(
        conversationId: 'c1',
        preview: 'latest',
        messageAt: later,
      );

      final row = await database.conversationDao.findConversation('c1');

      expect(row!.lastMessagePreview, 'latest');
      expect(row.lastMessageAt, later);
    });

    test('does not reorder the rail when back-filling history', () async {
      await database.conversationDao.upsertConversation(
        _conversation(lastMessageAt: testEpoch.add(const Duration(hours: 1))),
      );

      await database.conversationDao.touchWithMessage(
        conversationId: 'c1',
        preview: 'ancient',
        messageAt: testEpoch.subtract(const Duration(days: 5)),
      );

      final row = await database.conversationDao.findConversation('c1');

      // Loading history must not put an old thread back on top.
      expect(row!.lastMessageAt, testEpoch.add(const Duration(hours: 1)));
      expect(row.lastMessagePreview, isNull);
    });

    test('ignores a touch for a conversation that is not stored', () async {
      await database.conversationDao.touchWithMessage(
        conversationId: 'missing',
        preview: 'x',
        messageAt: testEpoch,
      );

      expect(
        await database.conversationDao.findConversation('missing'),
        isNull,
      );
    });
  });

  group('messages', () {
    setUp(() async {
      await database.conversationDao.upsertConversation(_conversation());
    });

    test('reads a thread newest first, capped', () async {
      for (var index = 0; index < 5; index++) {
        await database.conversationDao.upsertMessage(
          _message(
            id: 'm$index',
            createdAt: testEpoch.add(Duration(minutes: index)),
          ),
        );
      }

      final rows = await database.conversationDao
          .watchMessages('c1', limit: 3)
          .first;

      // Descending with a limit reads the newest page from the index; the
      // domain service flips it into reading order.
      expect(rows.map((r) => r.id), <String>['m4', 'm3', 'm2']);
    });

    test('finds an optimistic row by its idempotency key', () async {
      await database.conversationDao.upsertMessage(
        _message(clientMessageId: 'client-1'),
      );

      final row = await database.conversationDao.findByClientMessageId(
        'client-1',
      );

      expect(row!.id, 'm1');
    });

    test('reports the oldest message as the history cursor', () async {
      await database.conversationDao.upsertMessage(
        _message(
          id: 'newer',
          createdAt: testEpoch.add(const Duration(days: 1)),
        ),
      );
      await database.conversationDao.upsertMessage(
        _message(id: 'older', createdAt: testEpoch),
      );

      final oldest = await database.conversationDao.oldestMessage('c1');

      expect(oldest!.id, 'older');
    });

    test('writes a page atomically', () async {
      final written = await database.conversationDao.upsertMessages(
        <MessagesCompanion>[
          _message(id: 'a'),
          _message(id: 'b'),
          _message(id: 'c'),
        ],
      );

      expect(written, 3);
      expect(
        await database.conversationDao.watchMessages('c1').first,
        hasLength(3),
      );
    });

    test('re-keys an optimistic row to the server id, in place', () async {
      await database.conversationDao.upsertMessage(
        _message(
          id: 'client-1',
          clientMessageId: 'client-1',
          state: MessageStateRow.pending,
        ),
      );

      await database.conversationDao.rekeyMessage(
        fromId: 'client-1',
        toId: 'server-1',
        changes: MessagesCompanion(
          clientMessageId: const Value<String?>('client-1'),
          state: const Value<MessageStateRow>(MessageStateRow.sent),
        ),
      );

      final rows = await database.conversationDao.watchMessages('c1').first;

      // One row, re-keyed -- not two. A duplicate here is the optimistic
      // bubble and its acknowledged twin sitting side by side on screen.
      expect(rows, hasLength(1));
      expect(rows.single.id, 'server-1');
      expect(rows.single.clientMessageId, 'client-1');
      expect(rows.single.state, MessageStateRow.sent);
    });

    test('re-keying a message that is gone is a no-op', () async {
      await database.conversationDao.rekeyMessage(
        fromId: 'missing',
        toId: 'server-1',
        changes: const MessagesCompanion(),
      );

      expect(await database.conversationDao.findMessage('server-1'), isNull);
    });
  });

  group('clear', () {
    test('removes conversations and their messages', () async {
      await database.conversationDao.upsertConversation(_conversation());
      await database.conversationDao.upsertMessage(_message());

      await database.conversationDao.clear();

      expect(
        await database.conversationDao.watchConversations().first,
        isEmpty,
      );
      expect(await database.conversationDao.findMessage('m1'), isNull);
    });
  });
}
