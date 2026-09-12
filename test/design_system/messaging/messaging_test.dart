import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/feedback/async_view.dart';
import 'package:tajeerai_mobile/design_system/feedback/error_state.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_ar.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_en.dart';
import 'package:tajeerai_mobile/design_system/messaging/day_and_system_lines.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_bubble.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_data.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_status_icon.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_timeline.dart';
import 'package:tajeerai_mobile/design_system/messaging/typing_indicator.dart';

import '../../support/widget_harness.dart';

AppMessageData _message({
  String id = 'm1',
  AppMessageSide side = AppMessageSide.outgoing,
  String? text = 'See you then',
  AppMessageKind kind = AppMessageKind.text,
  AppMessageStatus status = AppMessageStatus.none,
  DateTime? at,
  bool bot = false,
}) => AppMessageData(
  id: id,
  side: side,
  sentAt: at ?? DateTime(2026, 3, 12, 10, 24),
  text: text,
  kind: kind,
  status: status,
  isFromBot: bot,
);

BoxDecoration _bubbleOf(WidgetTester tester, String text) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

void main() {
  group('AppMessageBubble', () {
    testWidgets(
      'incoming on a card at the start; outgoing on the wash at the end',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapWidget(
            Column(
              children: <Widget>[
                AppMessageBubble(
                  message: _message(side: AppMessageSide.incoming, text: 'hi'),
                ),
                AppMessageBubble(
                  message: _message(
                    text: 'hello',
                    status: AppMessageStatus.sent,
                  ),
                ),
              ],
            ),
          ),
        );

        final BuildContext context = tester.element(find.text('hi'));
        final double middle =
            tester.getSize(find.byType(Column).first).width / 2;

        expect(tester.getCenter(find.text('hi')).dx, lessThan(middle));
        expect(tester.getCenter(find.text('hello')).dx, greaterThan(middle));
        expect(_bubbleOf(tester, 'hi').color, context.elevation.card.tone);
        // The token file names this wash for exactly this: the outgoing bubble.
        expect(_bubbleOf(tester, 'hello').color, context.colors.primarySoft);
      },
    );

    test('the tail is the speaker\'s bottom corner, and it mirrors', () {
      const Radius round = Radius.circular(TajeerRadii.lg);
      const Radius tight = Radius.circular(TajeerRadii.sm);

      BorderRadius resolved(bool outgoing, TextDirection direction) =>
          AppMessageBubble.radiusFor(
            outgoing: outgoing,
            startsRun: true,
          ).resolve(direction);

      expect(resolved(true, TextDirection.ltr).bottomRight, tight);
      expect(resolved(true, TextDirection.ltr).bottomLeft, round);
      expect(resolved(true, TextDirection.rtl).bottomLeft, tight);
      expect(resolved(false, TextDirection.ltr).bottomLeft, tight);
      expect(resolved(false, TextDirection.rtl).bottomRight, tight);

      // Inside a run the join is tightened too, on the speaker's side only.
      final BorderRadius joined = AppMessageBubble.radiusFor(
        outgoing: true,
        startsRun: false,
      ).resolve(TextDirection.ltr);
      expect(joined.topRight, tight);
      expect(joined.topLeft, round);
    });

    testWidgets('only the last of a run carries the time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(status: AppMessageStatus.read),
            endsRun: false,
          ),
        ),
      );
      expect(find.text('10:24'), findsNothing);

      // ...unless its delivery has something to say, which every bubble does.
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(status: AppMessageStatus.queued),
            endsRun: false,
          ),
        ),
      );
      expect(find.text('10:24'), findsOneWidget);
      expect(find.text(appMessagesEn.queued), findsOneWidget);
    });

    /*
      Delivery does not collapse with the time. A single tick under the last of
      a run said nothing about the messages above it, and "did that one
      arrive?" is a question about a message.
    */
    testWidgets('every outgoing bubble carries its own delivery state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(status: AppMessageStatus.read),
            endsRun: false,
          ),
        ),
      );

      expect(find.byType(AppMessageStatusIcon), findsOneWidget);
      // Still no time: that one does collapse to the end of the run.
      expect(find.text('10:24'), findsNothing);
    });

    testWidgets('an incoming bubble mid-run carries neither', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(
              side: AppMessageSide.incoming,
              status: AppMessageStatus.none,
            ),
            endsRun: false,
          ),
        ),
      );

      expect(find.byType(AppMessageStatusIcon), findsNothing);
      expect(find.text('10:24'), findsNothing);
    });

    testWidgets('a failed send is outlined, says so, and offers buttons', (
      WidgetTester tester,
    ) async {
      int retried = 0;
      int discarded = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(status: AppMessageStatus.notSent),
            onRetry: () => retried++,
            onDiscard: () => discarded++,
          ),
        ),
      );

      final BuildContext context = tester.element(find.text('See you then'));
      expect(
        (_bubbleOf(tester, 'See you then').border! as Border).top.color,
        context.colors.dangerDefault,
      );
      expect(find.text(appMessagesEn.notSent), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, appMessagesEn.retry));
      await tester.tap(find.widgetWithText(AppButton, appMessagesEn.discard));
      expect(retried, 1);
      expect(discarded, 1);
    });

    testWidgets('reads as one sentence: what, when, how it went', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(message: _message(status: AppMessageStatus.read)),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'See you then, 10:24, ${appMessagesEn.readReceipt}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('media is a labelled line; what cannot be drawn says so', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          Column(
            children: <Widget>[
              AppMessageBubble(
                message: _message(
                  kind: AppMessageKind.image,
                  text: 'This colour',
                ),
              ),
              AppMessageBubble(
                message: _message(
                  id: 'm2',
                  kind: AppMessageKind.unsupported,
                  text: null,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text(appMessagesEn.photo), findsOneWidget);
      expect(find.text('This colour'), findsOneWidget);
      expect(find.byIcon(LucideIcons.image), findsOneWidget);
      expect(find.text(appMessagesEn.unsupportedMessage), findsOneWidget);
    });

    testWidgets('an English message in an Arabic thread keeps its direction', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: _message(
              side: AppMessageSide.incoming,
              text: 'Is it ready?',
            ),
          ),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Is it ready?')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('the assistant is named over its first bubble only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(AppMessageBubble(message: _message(bot: true))),
      );
      expect(find.text(appMessagesEn.bot), findsOneWidget);
      expect(find.byIcon(LucideIcons.bot), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(message: _message(bot: true), startsRun: false),
        ),
      );
      expect(find.text(appMessagesEn.bot), findsNothing);
    });

    testWidgets('large text grows a bubble without breaking it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: AppMessageBubble(
                message: _message(
                  text:
                      'A message long enough to wrap across several lines once '
                      'the reader has turned their text size all the way up',
                  status: AppMessageStatus.notSent,
                ),
                onRetry: () {},
                onDiscard: () {},
              ),
            ),
          ),
          textScaler: const TextScaler.linear(2),
          size: const Size(360, 800),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long press is reported', (WidgetTester tester) async {
      int held = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(message: _message(), onLongPress: () => held++),
        ),
      );

      await tester.longPress(find.text('See you then'));
      expect(held, 1);
    });
  });

  group('AppMessageStatusIcon', () {
    testWidgets('every status is a word to a screen reader; some show it', (
      WidgetTester tester,
    ) async {
      const Set<AppMessageStatus> worded = <AppMessageStatus>{
        AppMessageStatus.queued,
        AppMessageStatus.sending,
        AppMessageStatus.notSent,
        AppMessageStatus.removed,
      };

      for (final AppMessageStatus status in AppMessageStatus.values) {
        await tester.pumpWidget(
          wrapWidget(Center(child: AppMessageStatusIcon(status: status))),
        );
        await tester.pump();

        final String? label = AppMessageStatusIcon.labelFor(
          status,
          appMessagesEn,
        );
        if (label == null) {
          expect(status, AppMessageStatus.none);
          continue;
        }
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: '$status');
        expect(
          find.text(label),
          worded.contains(status) ? findsOneWidget : findsNothing,
          reason: '$status',
        );
      }
    });

    testWidgets('read is tinted; delivered is not', (
      WidgetTester tester,
    ) async {
      Future<Color?> tick(AppMessageStatus status) async {
        await tester.pumpWidget(
          wrapWidget(Center(child: AppMessageStatusIcon(status: status))),
        );
        return tester.widget<Icon>(find.byType(Icon)).color;
      }

      final Color? delivered = await tick(AppMessageStatus.delivered);
      final Color? read = await tick(AppMessageStatus.read);
      final BuildContext context = tester.element(find.byType(Icon));

      expect(delivered, context.colors.textMuted);
      expect(read, context.colors.infoDefault);
    });
  });

  group('day and system lines', () {
    testWidgets('a day is today, yesterday or a date, as a heading', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime(2026, 3, 12, 18);

      await tester.pumpWidget(
        wrapWidget(AppDateSeparator(day: DateTime(2026, 3, 12), now: now)),
      );
      expect(find.text(appMessagesEn.today), findsOneWidget);
      expect(
        tester.getSemantics(find.text(appMessagesEn.today)),
        isSemantics(isHeader: true),
      );

      await tester.pumpWidget(
        wrapWidget(
          AppDateSeparator(day: DateTime(2026, 3, 11), now: now),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      expect(find.text(appMessagesAr.yesterday), findsOneWidget);
    });

    testWidgets('a system line belongs to neither side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(
            width: 400,
            child: AppSystemMessage(text: 'Assigned to Ahmed'),
          ),
        ),
      );

      expect(
        tester.getCenter(find.text('Assigned to Ahmed')).dx,
        moreOrLessEquals(200, epsilon: 1),
      );
    });
  });

  group('AppTypingIndicator', () {
    testWidgets('says who is typing, as a live region', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(const AppTypingIndicator(name: 'Sara')),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Sara is typing…')),
        isSemantics(isLiveRegion: true),
      );

      await tester.pumpWidget(wrapWidget(const AppTypingIndicator()));
      await tester.pump();
      expect(find.bySemanticsLabel(appMessagesEn.typing), findsOneWidget);
    });

    testWidgets('pulses, and holds still when motion is reduced', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const AppTypingIndicator()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        wrapWidget(const AppTypingIndicator(), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppMessageTimeline', () {
    Widget timeline(
      AppViewState<List<AppMessageData>> state, {
      int unreadCount = 0,
      bool typing = false,
      ValueChanged<AppMessageData>? onRetry,
    }) => wrapWidget(
      SizedBox(
        height: 600,
        child: AppMessageTimeline(
          state: state,
          emptyTitle: 'No messages yet',
          unreadCount: unreadCount,
          typing: typing,
          onRetry: onRetry,
          now: DateTime(2026, 3, 12, 18),
        ),
      ),
    );

    testWidgets('loading is placeholder bubbles, and one word to a reader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        timeline(const AppViewLoading<List<AppMessageData>>()),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(appMessagesEn.loading), findsOneWidget);
      expect(find.byType(AppMessageBubble), findsNothing);
    });

    testWidgets('empty says what the app passed — unless somebody is typing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        timeline(const AppViewLoaded<List<AppMessageData>>(<AppMessageData>[])),
      );
      expect(find.text('No messages yet'), findsOneWidget);

      await tester.pumpWidget(
        timeline(
          const AppViewLoaded<List<AppMessageData>>(<AppMessageData>[]),
          typing: true,
        ),
      );
      await tester.pump();
      expect(find.text('No messages yet'), findsNothing);
      expect(find.byType(AppTypingIndicator), findsOneWidget);
    });

    testWidgets('failed shows the app\'s words and retries', (
      WidgetTester tester,
    ) async {
      int retried = 0;
      await tester.pumpWidget(
        timeline(
          AppViewFailed<List<AppMessageData>>(
            'The thread could not be read.',
            onRetry: () => retried++,
          ),
        ),
      );

      expect(find.text('The thread could not be read.'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AppErrorState),
          matching: find.byType(AppButton),
        ),
      );
      expect(retried, 1);
    });

    testWidgets('newest at the bottom, under its day, after the marker', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        timeline(
          AppViewLoaded<List<AppMessageData>>(<AppMessageData>[
            _message(
              id: 'm1',
              side: AppMessageSide.incoming,
              text: 'first',
              at: DateTime(2026, 3, 11, 20),
            ),
            _message(
              id: 'm2',
              side: AppMessageSide.incoming,
              text: 'second',
              at: DateTime(2026, 3, 12, 9),
            ),
            _message(
              id: 'm3',
              side: AppMessageSide.incoming,
              text: 'third',
              at: DateTime(2026, 3, 12, 9, 1),
            ),
          ]),
          unreadCount: 2,
        ),
      );

      double y(String text) => tester.getCenter(find.text(text)).dy;

      expect(find.text(appMessagesEn.yesterday), findsOneWidget);
      expect(find.text(appMessagesEn.today), findsOneWidget);
      expect(find.text('2 unread'), findsOneWidget);
      expect(y('first'), lessThan(y('2 unread')));
      expect(y('2 unread'), lessThan(y('second')));
      expect(y('second'), lessThan(y('third')));
    });

    testWidgets('retry reaches the app with the message it belongs to', (
      WidgetTester tester,
    ) async {
      final List<String> retried = <String>[];
      await tester.pumpWidget(
        timeline(
          AppViewLoaded<List<AppMessageData>>(<AppMessageData>[
            _message(id: 'm7', status: AppMessageStatus.notSent),
          ]),
          onRetry: (AppMessageData message) => retried.add(message.id),
        ),
      );

      await tester.tap(find.widgetWithText(AppButton, appMessagesEn.retry));
      expect(retried, <String>['m7']);
    });
  });
}
