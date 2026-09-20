import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/design_system/primitives/pressable.dart';

import '../../support/widget_harness.dart';

void main() {
  testWidgets('speaking for its children, it can still be pressed', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    int holds = 0;
    await tester.pumpWidget(
      wrapWidget(
        Center(
          child: AppPressable(
            onTap: () => taps++,
            onLongPress: () => holds++,
            semanticLabel: 'Open the thread with Ada',
            excludeSemantics: true,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ada'),
            ),
          ),
        ),
      ),
    );

    // One sentence, not the sentence and then the fragments again.
    expect(find.bySemanticsLabel('Ada'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Open the thread with Ada')),
      isSemantics(isButton: true, hasTapAction: true, hasLongPressAction: true),
    );

    // Excluding the children dropped the gesture's own actions with them; the
    // node has to carry its own, or a screen reader hears it and cannot press.
    tester.semantics.tap(find.semantics.byLabel('Open the thread with Ada'));
    tester.semantics.longPress(
      find.semantics.byLabel('Open the thread with Ada'),
    );
    expect(taps, 1);
    expect(holds, 1);
  });

  testWidgets('without a label of its own, its children speak', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWidget(
        Center(
          child: AppPressable(onTap: () {}, child: const Text('Ada')),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Ada'), findsOneWidget);
  });
}
