import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/design_system/overlays/action_sheet.dart';

import '../../support/widget_harness.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    List<AppAction> actions, {
    bool showCancel = true,
  }) async {
    await tester.pumpWidget(
      wrapWidget(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => AppActionSheet.show(
              context: context,
              title: 'سارة أحمد',
              actions: actions,
              showCancel: showCancel,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('runs the chosen action once, and closes', (
    WidgetTester tester,
  ) async {
    // `show` completes when the route is popped, not when it has finished
    // animating out — measured, not assumed: the callback runs on the first
    // pump after the tap. What that buys is still the thing worth having: by
    // the time an action runs, the sheet is no longer the route taking input.
    final List<String> events = <String>[];

    await open(tester, <AppAction>[
      AppAction(label: 'تثبيت', onSelected: () => events.add('selected')),
      AppAction(label: 'كتم', onSelected: () => events.add('muted')),
    ]);

    await tester.tap(find.text('تثبيت'));
    await tester.pumpAndSettle();

    expect(events, <String>[
      'selected',
    ], reason: 'once, and only the one tapped');
    expect(find.text('تثبيت'), findsNothing, reason: 'the sheet is gone');
  });

  testWidgets('reports nothing when cancelled', (WidgetTester tester) async {
    int selections = 0;

    await open(tester, <AppAction>[
      AppAction(label: 'تثبيت', onSelected: () => selections++),
    ]);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(selections, 0);
  });

  testWidgets('cancel can be turned off, for a sheet with its own escape', (
    WidgetTester tester,
  ) async {
    await open(tester, <AppAction>[
      AppAction(label: 'تثبيت', onSelected: () {}),
    ], showCancel: false);

    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('a disabled action cannot be chosen', (
    WidgetTester tester,
  ) async {
    int selections = 0;

    await open(tester, <AppAction>[
      AppAction(
        label: 'حذف',
        enabled: false,
        destructive: true,
        onSelected: () => selections++,
      ),
    ]);

    await tester.tap(find.text('حذف'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(selections, 0);
    expect(find.text('حذف'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('every action gets a 52px row', (WidgetTester tester) async {
    await open(tester, <AppAction>[
      AppAction(label: 'تثبيت', onSelected: () {}),
      AppAction(label: 'كتم', onSelected: () {}),
    ]);

    for (final String label in <String>['تثبيت', 'كتم']) {
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(52),
        reason: label,
      );
    }
  });
}
