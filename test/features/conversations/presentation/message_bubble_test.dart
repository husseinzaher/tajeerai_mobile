import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/widgets/message_bubble.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/widget_harness.dart';

Message _message({
  MessageState state = MessageState.sent,
  MessageDirection direction = MessageDirection.outbound,
  String? body = 'hello there',
  String type = 'text',
  String? mediaUrl,
}) {
  return Message(
    id: 'm1',
    conversationId: 'c1',
    direction: direction,
    state: state,
    type: type,
    body: body,
    mediaUrl: mediaUrl,
    createdAt: testEpoch,
  );
}

void main() {
  group('rendering', () {
    testWidgets('shows the message body', (tester) async {
      await tester.pumpWidget(wrapWidget(MessageBubble(message: _message())));

      expect(find.text('hello there'), findsOneWidget);
    });

    testWidgets('uses primary for outbound and muted for inbound', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWidget(MessageBubble(message: _message())));

      var container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MessageBubble),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        (container.decoration! as BoxDecoration).color,
        TajeerColors.tajeerLight.primary,
      );

      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(direction: MessageDirection.inbound)),
        ),
      );

      container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MessageBubble),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        (container.decoration! as BoxDecoration).color,
        TajeerColors.tajeerLight.surfaceMuted,
      );
    });

    testWidgets('renders in both appearances', (tester) async {
      await pumpInBothThemes(tester, MessageBubble(message: _message()), (
        tester,
        brightness,
      ) async {
        expect(find.text('hello there'), findsOneWidget);
      });
    });

    testWidgets('mirrors for Arabic without a second layout', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message()),
          textDirection: TextDirection.rtl,
        ),
      );

      final align = tester.widget<Align>(
        find
            .descendant(
              of: find.byType(MessageBubble),
              matching: find.byType(Align),
            )
            .first,
      );

      // Logical, not left/right: the same widget has to work in both
      // directions, which is the design system's own rule.
      expect(align.alignment, AlignmentDirectional.centerEnd);
    });
  });

  group('delivery states', () {
    testWidgets('a pending message says it is waiting', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(state: MessageState.pending)),
        ),
      );

      expect(find.text('Waiting to send'), findsOneWidget);
      expect(find.byIcon(LucideIcons.clock), findsOneWidget);
    });

    testWidgets('a sending message shows a spinner', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(state: MessageState.sending)),
        ),
      );
      await tester.pump();

      expect(find.text('Sending'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a sent message shows a single tick', (tester) async {
      await tester.pumpWidget(wrapWidget(MessageBubble(message: _message())));

      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('a delivered message shows a double tick', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(state: MessageState.delivered)),
        ),
      );

      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
    });

    testWidgets('a read message tints the double tick', (tester) async {
      await tester.pumpWidget(
        wrapWidget(MessageBubble(message: _message(state: MessageState.read))),
      );

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.checkCheck));

      expect(icon.color, TajeerColors.tajeerLight.infoDefault);
    });

    testWidgets('an inbound message shows no delivery state', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(
            message: _message(
              direction: MessageDirection.inbound,
              state: MessageState.delivered,
            ),
          ),
        ),
      );

      // Delivery is about our own outbound messages; showing ticks on an
      // inbound one would be meaningless.
      expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
    });
  });

  group('failed messages', () {
    testWidgets('outlines the bubble and says it was not sent', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(state: MessageState.failed)),
        ),
      );

      expect(find.text('Not sent'), findsOneWidget);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MessageBubble),
              matching: find.byType(Container),
            )
            .first,
      );

      expect((container.decoration! as BoxDecoration).border, isNotNull);
    });

    testWidgets('offers retry and discard', (tester) async {
      var retries = 0;
      var discards = 0;

      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(
            message: _message(state: MessageState.failed),
            onRetry: () => retries += 1,
            onDiscard: () => discards += 1,
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Discard'));
      await tester.pump();

      expect(retries, 1);
      expect(discards, 1);
    });

    testWidgets('offers no actions on a sent message', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(), onRetry: () {}, onDiscard: () {}),
        ),
      );

      expect(find.text('Retry'), findsNothing);
    });
  });

  group('unsupported content', () {
    testWidgets('renders a placeholder rather than an empty bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(message: _message(body: null, type: 'sticker')),
        ),
      );

      // The provider's type vocabulary grows server-side; an unknown type must
      // degrade, not crash a list.
      expect(find.text('Unsupported message'), findsOneWidget);
    });

    testWidgets('labels an attachment with no body', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          MessageBubble(
            message: _message(
              body: null,
              type: 'image',
              mediaUrl: 'https://cdn.test/a.png',
            ),
          ),
        ),
      );

      expect(find.text('Attachment'), findsOneWidget);
    });
  });
}
