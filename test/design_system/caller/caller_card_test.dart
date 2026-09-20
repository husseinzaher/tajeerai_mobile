import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/design_system/caller/caller_card.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppCallerCard', () {
    testWidgets('an unknown caller keeps the number left to right in Arabic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppCallerCard(
            data: AppCallerCardData(
              phoneNumber: '+966501234567',
              directionLabel: 'مكالمة واردة',
            ),
          ),
          textDirection: TextDirection.rtl,
        ),
      );

      // With no name, the number is the primary label. Laid out in the page's
      // direction it would read "966501234567+".
      expect(
        tester.widget<Text>(find.text('+966501234567')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('a named caller shows the name, the number and the store', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppCallerCard(
            data: AppCallerCardData(
              phoneNumber: '+966501234567',
              directionLabel: 'مكالمة واردة',
              displayName: 'سارة أحمد',
              businessName: 'متجر النخبة',
              tags: <String>['مميز'],
            ),
          ),
          textDirection: TextDirection.rtl,
        ),
      );

      expect(find.text('سارة أحمد'), findsOneWidget);
      expect(find.text('+966501234567'), findsOneWidget);
      expect(find.text('متجر النخبة'), findsOneWidget);
      expect(find.text('مميز'), findsOneWidget);
    });

    testWidgets('the member can turn every optional line off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppCallerCard(
            data: AppCallerCardData(
              phoneNumber: '+966501234567',
              directionLabel: 'مكالمة واردة',
              displayName: 'سارة أحمد',
              businessName: 'متجر النخبة',
              spamLabel: 'مشتبه به',
              tags: <String>['مميز'],
              showCallerName: false,
              showPhoneNumber: false,
              showBusinessInfo: false,
              showSpamStatus: false,
              showTags: false,
            ),
          ),
        ),
      );

      expect(find.text('سارة أحمد'), findsNothing);
      expect(find.text('+966501234567'), findsNothing);
      expect(find.text('متجر النخبة'), findsNothing);
      expect(find.text('مشتبه به'), findsNothing);
      expect(find.text('مميز'), findsNothing);
      expect(find.text('مكالمة واردة'), findsOneWidget);
    });

    testWidgets('tapping the card reports it once', (
      WidgetTester tester,
    ) async {
      int taps = 0;

      await tester.pumpWidget(
        wrapWidget(
          AppCallerCard(
            data: const AppCallerCardData(
              phoneNumber: '+966501234567',
              directionLabel: 'مكالمة واردة',
            ),
            onTap: () => taps += 1,
          ),
        ),
      );

      await tester.tap(find.byType(AppCallerCard));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
