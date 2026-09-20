import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/design_system/display/avatar.dart';
import 'package:TajeerAi/design_system/display/badge.dart';
import 'package:TajeerAi/design_system/display/profile_header.dart';
import 'package:TajeerAi/design_system/loaders/skeleton.dart';

import '../../support/widget_harness.dart';

List<AppProfileAction> _actions(List<String> labels, {VoidCallback? onCall}) {
  return <AppProfileAction>[
    for (final String label in labels)
      AppProfileAction(
        icon: LucideIcons.phone,
        label: label,
        onPressed: onCall ?? () {},
      ),
  ];
}

void main() {
  group('AppProfileHeader', () {
    testWidgets('shows the person, what they are, and what can be done', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppProfileHeader(
            name: 'Sara Ahmed',
            subtitle: 'Elite Store',
            badges: const <Widget>[AppBadge(label: 'VIP')],
            actions: _actions(<String>['Call'], onCall: () => calls++),
          ),
        ),
      );

      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('Elite Store'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.phone));
      expect(calls, 1);
    });

    testWidgets('an action is heard once, by its word', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWidget(
          AppProfileHeader(name: 'Sara', actions: _actions(<String>['Call'])),
        ),
      );

      expect(find.bySemanticsLabel('Call'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('offers three actions at most', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          AppProfileHeader(
            name: 'Sara',
            actions: _actions(<String>['One', 'Two', 'Three', 'Four']),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('compact is a row that opens the person', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppProfileHeader(
            name: 'Sara Ahmed',
            subtitle: 'Elite Store',
            compact: true,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Sara Ahmed'));
      expect(taps, 1);
    });

    testWidgets('compact starts at the start edge: the right, in Arabic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppProfileHeader(name: 'سارة أحمد', compact: true),
          textDirection: TextDirection.rtl,
        ),
      );

      expect(
        tester.getCenter(find.byType(AppAvatar)).dx,
        greaterThan(tester.getCenter(find.text('سارة أحمد')).dx),
      );
    });

    testWidgets('a placeholder is heard as loading, not as a blank name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(const AppProfileHeader.placeholder()));

      expect(find.byType(AppSkeleton), findsWidgets);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('twice the text size on a narrow phone still fits', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWidget(
          Column(
            children: <Widget>[
              AppProfileHeader(
                name: 'Sara Abdulrahman Al-Qahtani',
                subtitle: 'Elite Store for Perfumes and Gifts',
                badges: const <Widget>[
                  AppBadge(label: 'VIP'),
                  AppBadge(label: 'Riyadh'),
                ],
                actions: _actions(<String>['Call', 'Message', 'Add a note']),
              ),
              AppProfileHeader(
                name: 'Sara Abdulrahman Al-Qahtani',
                subtitle: 'Elite Store for Perfumes and Gifts',
                badges: const <Widget>[AppBadge(label: 'VIP')],
                actions: _actions(<String>['Call']),
                compact: true,
              ),
            ],
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
