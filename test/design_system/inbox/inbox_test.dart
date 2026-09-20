import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/buttons/app_button.dart';
import 'package:TajeerAi/design_system/channels/channel_descriptor.dart';
import 'package:TajeerAi/design_system/channels/channel_glyph.dart';
import 'package:TajeerAi/design_system/display/avatar.dart';
import 'package:TajeerAi/design_system/display/badge.dart';
import 'package:TajeerAi/design_system/display/list_item.dart';
import 'package:TajeerAi/design_system/feedback/async_view.dart';
import 'package:TajeerAi/design_system/feedback/error_state.dart';
import 'package:TajeerAi/design_system/feedback/loading_state.dart';
import 'package:TajeerAi/design_system/inbox/conversation_list.dart';
import 'package:TajeerAi/design_system/inbox/conversation_list_item.dart';
import 'package:TajeerAi/design_system/inbox/conversation_summary.dart';
import 'package:TajeerAi/design_system/localization/ds_messages_ar.dart';
import 'package:TajeerAi/design_system/localization/ds_messages_en.dart';

import '../../support/widget_harness.dart';

/// A fixed "today", so a row's time reads the same on any date.
final DateTime _now = DateTime(2026, 3, 12, 18, 30);

AppConversationSummary _summary({
  String id = 'c1',
  String title = 'Ada Lovelace',
  String? preview = 'See you then',
  int unread = 0,
  int failed = 0,
  bool pinned = false,
  bool muted = false,
  AppChannelDescriptor? channel,
  DateTime? at,
}) => AppConversationSummary(
  id: id,
  title: title,
  preview: preview,
  lastActivityAt: at ?? DateTime(2026, 3, 12, 10, 24),
  unreadCount: unread,
  failedCount: failed,
  isPinned: pinned,
  isMuted: muted,
  channel: channel,
);

void main() {
  group('AppConversationSummary', () {
    test('is equal when everything a row draws is equal', () {
      expect(_summary(), _summary());
      expect(_summary().hashCode, _summary().hashCode);
      expect(_summary(unread: 1), isNot(_summary()));
      expect(_summary(unread: 1).hasUnread, isTrue);
      expect(_summary().hasUnread, isFalse);
      expect(_summary(failed: 1), isNot(_summary()));
      expect(_summary(failed: 1).hasFailed, isTrue);
      expect(_summary().hasFailed, isFalse);
    });
  });

  group('AppConversationListItem', () {
    Widget row(
      AppConversationSummary summary, {
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) => AppConversationListItem(
      conversation: summary,
      onTap: onTap ?? () {},
      onLongPress: onLongPress,
      now: _now,
    );

    testWidgets('shows who, what was said, and when', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(row(_summary())));

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('See you then'), findsOneWidget);
      expect(find.text('10:24'), findsOneWidget);
    });

    testWidgets('yesterday is a word, in the reader\'s language', (
      WidgetTester tester,
    ) async {
      final AppConversationSummary summary = _summary(
        at: DateTime(2026, 3, 11, 9),
      );

      await tester.pumpWidget(wrapWidget(row(summary)));
      expect(find.text(appMessagesEn.yesterday), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(
          row(summary),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();
      expect(find.text(appMessagesAr.yesterday), findsOneWidget);
    });

    testWidgets('unread is weight and a count, never a colour on the text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(row(_summary(unread: 3))));

      final BuildContext context = tester.element(
        find.byType(AppConversationListItem),
      );
      final TextStyle title = DefaultTextStyle.of(
        tester.element(find.text('Ada Lovelace')),
      ).style;
      final TextStyle time = DefaultTextStyle.of(
        tester.element(find.text('10:24')),
      ).style;

      expect(find.byType(AppBadge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(title.fontWeight, FontWeight.w700);
      // The row this replaced drew the time in the brand yellow: 1.53:1.
      expect(time.color, context.colors.textSecondary);
      expect(time.color, isNot(context.colors.primary));
    });

    testWidgets('a thread with a send that did not go out is marked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(row(_summary(failed: 2, unread: 3))));

      // Two numbers that mean opposite things - work waiting, and work that
      // was done and did not land - so they are told apart by colour and a
      // glyph rather than by being read.
      expect(find.byType(AppBadge), findsNWidgets(2));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);

      final Semantics semantics = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(AppConversationListItem),
              matching: find.byType(Semantics),
            )
            .first,
      );

      expect(semantics.properties.label, contains('2 not sent'));
    });

    testWidgets('a read row has no badge', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWidget(row(_summary())));

      expect(find.byType(AppBadge), findsNothing);
    });

    testWidgets('pinned and muted rows are marked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(row(_summary(pinned: true, muted: true))),
      );

      expect(find.byIcon(LucideIcons.pin), findsOneWidget);
      expect(find.byIcon(LucideIcons.bellOff), findsOneWidget);
    });

    testWidgets('the channel rides on the avatar\'s corner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          row(
            _summary(
              channel: const AppChannelDescriptor(
                kind: AppChannelKind.whatsapp,
                label: 'WhatsApp',
              ),
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppAvatar),
          matching: find.byType(AppChannelGlyph),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(wrapWidget(row(_summary())));
      expect(find.byType(AppChannelGlyph), findsNothing);
    });

    testWidgets('reads as one sentence, and a screen reader can open it', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await tester.pumpWidget(
        wrapWidget(
          row(_summary(unread: 3, pinned: true), onTap: () => opened++),
        ),
      );

      const String sentence =
          'Ada Lovelace, 3 unread, Pinned, See you then, 10:24';
      expect(
        tester.getSemantics(find.byType(AppListItem)),
        isSemantics(label: sentence, isButton: true, hasTapAction: true),
      );

      tester.semantics.tap(find.semantics.byLabel(sentence));
      expect(opened, 1);
    });

    testWidgets('the sentence is Arabic when the reader is', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          row(_summary(title: 'سارة', preview: 'مرحباً', unread: 2)),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(AppListItem)).label,
        'سارة, 2 غير مقروءة, مرحباً, 10:24',
      );
    });

    testWidgets('the avatar sits at the start edge in both directions', (
      WidgetTester tester,
    ) async {
      await pumpInBothDirections(tester, row(_summary()), (
        WidgetTester tester,
        TextDirection direction,
      ) async {
        final double avatar = tester.getCenter(find.byType(AppAvatar)).dx;
        final double title = tester.getCenter(find.text('Ada Lovelace')).dx;

        expect(
          avatar,
          direction == TextDirection.rtl ? greaterThan(title) : lessThan(title),
        );
      });
    });

    testWidgets('a customer\'s words keep their own direction', (
      WidgetTester tester,
    ) async {
      // Laid out right-to-left, an English question in an Arabic Inbox reads
      // "?before it ships": the punctuation takes the paragraph's side.
      await tester.pumpWidget(
        wrapWidget(
          row(_summary(title: 'Lina Hassan', preview: 'Can it ship today?')),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();

      final Text english = tester.widget<Text>(find.text('Can it ship today?'));
      expect(english.textDirection, TextDirection.ltr);
      // Still aligned to the row's start, which is the right in Arabic.
      expect(english.textAlign, TextAlign.right);

      await tester.pumpWidget(
        wrapWidget(row(_summary(title: 'سارة', preview: 'هل الطلب جاهز؟'))),
      );
      final Text arabic = tester.widget<Text>(find.text('هل الطلب جاهز؟'));
      expect(arabic.textDirection, TextDirection.rtl);
      expect(arabic.textAlign, TextAlign.left);
    });

    testWidgets('large text makes the row taller, not broken', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          SizedBox(
            width: 360,
            child: row(
              _summary(
                title: 'A customer whose name is longer than any row',
                preview:
                    'A preview long enough to need both of its lines and '
                    'then an ellipsis at the end of the second one',
                unread: 128,
                pinned: true,
                muted: true,
              ),
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('a long press is reported apart from a tap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int holds = 0;
      await tester.pumpWidget(
        wrapWidget(
          row(_summary(), onTap: () => taps++, onLongPress: () => holds++),
        ),
      );

      await tester.tap(find.text('Ada Lovelace'));
      await tester.longPress(find.text('Ada Lovelace'));

      expect(taps, 1);
      expect(holds, 1);
    });
  });

  group('AppConversationList', () {
    Widget list(
      AppViewState<List<AppConversationSummary>> state, {
      ValueChanged<AppConversationSummary>? onOpen,
      Future<void> Function()? onRefresh,
      String? selectedId,
    }) => wrapWidget(
      SizedBox(
        height: 600,
        child: AppConversationList(
          state: state,
          onOpen: onOpen ?? (AppConversationSummary summary) {},
          onRefresh: onRefresh,
          emptyTitle: 'No conversations yet',
          emptyDescription: 'They appear here.',
          selectedId: selectedId,
          now: _now,
        ),
      ),
    );

    Future<void> pull(WidgetTester tester, Finder finder) async {
      await tester.fling(finder, const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'loading is placeholder rows, and one word to a screen reader',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          list(const AppViewLoading<List<AppConversationSummary>>()),
        );
        await tester.pump();

        expect(find.byType(AppLoadingState), findsOneWidget);
        expect(find.byType(AppConversationListItem), findsNothing);
        expect(find.bySemanticsLabel(appMessagesEn.loading), findsOneWidget);
      },
    );

    testWidgets('empty says what the app passed, and can still be pulled', (
      WidgetTester tester,
    ) async {
      int refreshed = 0;
      await tester.pumpWidget(
        list(
          const AppViewLoaded<List<AppConversationSummary>>(
            <AppConversationSummary>[],
          ),
          onRefresh: () async {
            refreshed++;
          },
        ),
      );

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('They appear here.'), findsOneWidget);

      await pull(tester, find.text('No conversations yet'));
      expect(refreshed, 1);
    });

    testWidgets('failed shows the app\'s message, retries, and pulls', (
      WidgetTester tester,
    ) async {
      int retried = 0;
      int refreshed = 0;
      await tester.pumpWidget(
        list(
          AppViewFailed<List<AppConversationSummary>>(
            'The list could not be read.',
            onRetry: () => retried++,
          ),
          onRefresh: () async {
            refreshed++;
          },
        ),
      );

      expect(find.text('The list could not be read.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AppErrorState),
          matching: find.byType(AppButton),
        ),
      );
      expect(retried, 1);

      await pull(tester, find.text('The list could not be read.'));
      expect(refreshed, 1);
    });

    testWidgets(
      'a row opens with its own summary; the selected one is marked',
      (WidgetTester tester) async {
        final List<AppConversationSummary> opened = <AppConversationSummary>[];
        final AppConversationSummary first = _summary();
        final AppConversationSummary second = _summary(
          id: 'c2',
          title: 'Grace Hopper',
        );

        await tester.pumpWidget(
          list(
            AppViewLoaded<List<AppConversationSummary>>(
              <AppConversationSummary>[first, second],
            ),
            onOpen: opened.add,
            selectedId: 'c2',
          ),
        );

        await tester.tap(find.text('Ada Lovelace'));
        expect(opened, <AppConversationSummary>[first]);
        expect(
          tester.widget<AppListItem>(find.byType(AppListItem).first).selected,
          isFalse,
        );
        expect(
          tester.widget<AppListItem>(find.byType(AppListItem).last).selected,
          isTrue,
        );
      },
    );
  });
}
