import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/display/status_dot.dart';
import 'package:TajeerAi/design_system/feedback/connection_banner.dart';
import 'package:TajeerAi/design_system/feedback/loading_state.dart';
import 'package:TajeerAi/design_system/feedback/status_banner.dart';
import 'package:TajeerAi/design_system/loaders/skeleton.dart';
import 'package:TajeerAi/design_system/loaders/spinner.dart';
import 'package:TajeerAi/design_system/localization/ds_messages_en.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppConnectionBanner', () {
    Future<AppStatusBanner?> shown(
      WidgetTester tester,
      AppConnectionBanner banner, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(wrapWidget(banner, locale: locale));
      await tester.pump();
      final Finder found = find.byType(AppStatusBanner);
      return found.evaluate().isEmpty
          ? null
          : tester.widget<AppStatusBanner>(found);
    }

    testWidgets('says nothing when current with nothing waiting', (
      WidgetTester tester,
    ) async {
      expect(
        await shown(
          tester,
          const AppConnectionBanner(status: AppConnectionStatus.current),
        ),
        isNull,
      );
    });

    testWidgets('each state says its own sentence, in its own tone', (
      WidgetTester tester,
    ) async {
      final List<(AppConnectionBanner, String, AppStatusTone)> cases =
          <(AppConnectionBanner, String, AppStatusTone)>[
            (
              const AppConnectionBanner(status: AppConnectionStatus.syncing),
              appMessagesEn.syncing,
              AppStatusTone.neutral,
            ),
            (
              const AppConnectionBanner(status: AppConnectionStatus.offline),
              '${appMessagesEn.showingSaved}. ${appMessagesEn.reconnecting}',
              AppStatusTone.warning,
            ),
            (
              const AppConnectionBanner(status: AppConnectionStatus.failed),
              appMessagesEn.showingSaved,
              AppStatusTone.warning,
            ),
            (
              const AppConnectionBanner(
                status: AppConnectionStatus.current,
                pending: 3,
              ),
              'Sending 3…',
              AppStatusTone.neutral,
            ),
            (
              const AppConnectionBanner(
                status: AppConnectionStatus.current,
                failed: 2,
              ),
              '2 not sent',
              AppStatusTone.warning,
            ),
          ];

      for (final (
            AppConnectionBanner banner,
            String message,
            AppStatusTone tone,
          )
          in cases) {
        final AppStatusBanner? banner0 = await shown(tester, banner);
        expect(banner0?.message, message);
        // Offline is a condition, not a failure: never the danger colour.
        expect(banner0?.tone, tone, reason: message);
      }
    });

    testWidgets('a failure outranks a send, and a phase outranks both', (
      WidgetTester tester,
    ) async {
      expect(
        (await shown(
          tester,
          const AppConnectionBanner(
            status: AppConnectionStatus.current,
            pending: 1,
            failed: 1,
          ),
        ))?.message,
        '1 not sent',
      );
      expect(
        (await shown(
          tester,
          const AppConnectionBanner(
            status: AppConnectionStatus.offline,
            pending: 2,
            failed: 1,
          ),
        ))?.message,
        '${appMessagesEn.showingSaved}. ${appMessagesEn.reconnecting}',
      );
    });

    testWidgets('the queue is counted in Arabic too', (
      WidgetTester tester,
    ) async {
      expect(
        (await shown(
          tester,
          const AppConnectionBanner(
            status: AppConnectionStatus.current,
            failed: 2,
          ),
          locale: const Locale('ar'),
        ))?.message,
        'تعذّر إرسال 2',
      );
    });

    testWidgets('a screen reader hears it change without looking for it', (
      WidgetTester tester,
    ) async {
      await shown(
        tester,
        const AppConnectionBanner(status: AppConnectionStatus.offline),
      );

      expect(
        tester.getSemantics(find.byType(AppStatusBanner)),
        isSemantics(isLiveRegion: true),
      );
    });
  });

  group('AppLoadingState', () {
    testWidgets('by default a spinner, and one word to a screen reader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const AppLoadingState()));
      await tester.pump();

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.bySemanticsLabel(appMessagesEn.loading), findsOneWidget);
    });

    testWidgets('as a list, the rows it was asked for', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(height: 800, child: AppLoadingState.list(rows: 3)),
        ),
      );
      await tester.pump();
      // A circle and two lines per row.
      expect(find.byType(AppSkeleton), findsNWidgets(9));
      expect(find.bySemanticsLabel(appMessagesEn.loading), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(
          const SizedBox(
            height: 800,
            child: AppLoadingState.list(rows: 3, leading: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppSkeleton), findsNWidgets(6));
    });
  });

  group('AppConnectionDot', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      Locale locale = const Locale('en'),
      TextDirection direction = TextDirection.ltr,
    }) async {
      await tester.pumpWidget(
        wrapWidget(child, locale: locale, textDirection: direction),
      );
      await tester.pump();
    }

    testWidgets('says nothing while current, which also means not yet asked', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const AppConnectionDot(status: AppConnectionStatus.current),
      );

      expect(find.byType(AppStatusDot), findsNothing);
    });

    testWidgets('every other state carries its own words', (
      WidgetTester tester,
    ) async {
      final Map<AppConnectionStatus, String> words =
          <AppConnectionStatus, String>{
            AppConnectionStatus.syncing: appMessagesEn.syncing,
            AppConnectionStatus.offline: appMessagesEn.offline,
            AppConnectionStatus.failed: appMessagesEn.syncFailed,
          };

      for (final MapEntry<AppConnectionStatus, String> entry in words.entries) {
        await pump(tester, AppConnectionDot(status: entry.key));

        expect(
          tester.widget<AppStatusDot>(find.byType(AppStatusDot)).semanticLabel,
          entry.value,
          reason: entry.key.name,
        );
      }
      // Offline and failed share a colour, so the words are all that tells
      // them apart. They must not be the same words.
      expect(words.values.toSet(), hasLength(words.length));
    });

    testWidgets('it and the banner never disagree about the same moment', (
      WidgetTester tester,
    ) async {
      for (final AppConnectionStatus status in AppConnectionStatus.values) {
        await pump(
          tester,
          Column(
            children: <Widget>[
              AppConnectionBanner(status: status),
              AppConnectionDot(status: status),
            ],
          ),
        );

        final Finder banner = find.byType(AppStatusBanner);
        final Finder dot = find.byType(AppStatusDot);
        expect(
          dot.evaluate().length,
          banner.evaluate().length,
          reason: '${status.name}: drawn by one and not the other',
        );

        if (banner.evaluate().isNotEmpty) {
          final TajeerColors colors = tester.element(dot).colors;
          expect(
            tester.widget<AppStatusDot>(dot).color == colors.warningDefault,
            tester.widget<AppStatusBanner>(banner).tone ==
                AppStatusTone.warning,
            reason: '${status.name}: a warning in one is a warning in both',
          );
        }
      }
    });

    testWidgets("its words go on screen when asked, in the reader's language", (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const AppConnectionDot(
          status: AppConnectionStatus.failed,
          showLabel: true,
        ),
        locale: const Locale('ar'),
        direction: TextDirection.rtl,
      );

      expect(find.textContaining('تعذّرت المزامنة'), findsOneWidget);
      expect(find.bySemanticsLabel('تعذّرت المزامنة'), findsOneWidget);
    });

    testWidgets('the dot leads its words from the start edge', (
      WidgetTester tester,
    ) async {
      for (final TextDirection direction in TextDirection.values) {
        await pump(
          tester,
          const AppConnectionDot(
            status: AppConnectionStatus.offline,
            showLabel: true,
          ),
          direction: direction,
        );

        final double dot = tester.getCenter(find.byType(AppStatusDot)).dx;
        final double whole = tester.getCenter(find.byType(AppConnectionDot)).dx;

        if (direction == TextDirection.ltr) {
          expect(dot, lessThan(whole), reason: 'ltr start = left');
        } else {
          expect(dot, greaterThan(whole), reason: 'rtl start = right');
        }
      }
    });
  });
}
