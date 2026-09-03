import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/widgets/conversation_tile.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/widget_harness.dart';

Conversation _conversation({
  String? customerName = 'Ada Lovelace',
  String? subject,
  int unreadCount = 0,
  bool isPinned = false,
  bool isMuted = false,
  String? preview = 'See you then',
}) {
  return Conversation(
    id: 'c1',
    state: ConversationState.open,
    customerName: customerName,
    subject: subject,
    unreadCount: unreadCount,
    isPinned: isPinned,
    isMuted: isMuted,
    lastMessagePreview: preview,
    lastMessageAt: testEpoch,
    createdAt: testEpoch,
  );
}

void main() {
  group('rendering', () {
    testWidgets('shows the customer name and preview', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(conversation: _conversation(), onTap: () {}),
        ),
      );

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('See you then'), findsOneWidget);
    });

    testWidgets('falls back to the subject when there is no name', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(
              customerName: null,
              subject: 'Order #42',
            ),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Order #42'), findsOneWidget);
    });

    testWidgets('falls back to a placeholder name when nothing is known', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(customerName: null),
            onTap: () {},
          ),
        ),
      );

      // A presentation fallback the backend explicitly says is never stored as
      // the name.
      expect(find.text('Unknown customer'), findsOneWidget);
    });

    testWidgets('says so when a thread has no messages', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(preview: null),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('No messages yet'), findsOneWidget);
    });
  });

  group('unread state', () {
    testWidgets('shows a badge with the count', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(unreadCount: 3),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows no badge when everything is read', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(conversation: _conversation(), onTap: () {}),
        ),
      );

      expect(find.text('0'), findsNothing);
    });
  });

  group('markers', () {
    testWidgets('shows a pin on a pinned thread', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(isPinned: true),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.pin), findsOneWidget);
    });

    testWidgets('shows a bell on a muted thread', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(isMuted: true),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.bellOff), findsOneWidget);
    });
  });

  group('interaction', () {
    testWidgets('opens the thread on tap', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(),
            onTap: () => taps += 1,
          ),
        ),
      );

      await tester.tap(find.byType(ConversationTile));
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('accessibility', () {
    testWidgets('reads as one sentence rather than five fragments', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          ConversationTile(
            conversation: _conversation(unreadCount: 2),
            onTap: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(ConversationTile));

      expect(semantics.label, contains('Ada Lovelace'));
      expect(semantics.label, contains('2 unread messages'));
    });
  });

  group('timestamp formatting', () {
    test('shows a time for today', () {
      final now = DateTime(2026, 3, 1, 18);
      final formatted = ConversationTile.formatTimestamp(
        DateTime(2026, 3, 1, 9, 30),
        now: now,
      );

      expect(formatted, contains(':'));
    });

    test('shows a weekday within the last week', () {
      final now = DateTime(2026, 3, 5, 12);
      final formatted = ConversationTile.formatTimestamp(
        DateTime(2026, 3, 3, 9),
        now: now,
      );

      // The rail is scanned, not read: a full date on every row is noise.
      expect(formatted.length, lessThanOrEqualTo(4));
    });

    test('shows a date beyond a week', () {
      final now = DateTime(2026, 3, 20, 12);
      final formatted = ConversationTile.formatTimestamp(
        DateTime(2026, 3, 1, 9),
        now: now,
      );

      expect(formatted, contains('/'));
    });
  });
}
