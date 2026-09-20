import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/design_system/display/detail_row.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppDetailRow', () {
    testWidgets('reads as one sentence: the label, then the value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWidget(
          const AppDetailRow(label: 'Phone', value: '+966 55 123 4567'),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'^Phone\s+\+966 55 123 4567$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('an identifier stays left to right on an Arabic page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppDetailRow(
            label: 'الهاتف',
            value: '+966 55 123 4567',
            identifier: true,
          ),
          textDirection: TextDirection.rtl,
        ),
      );

      // Laid out right to left, the "+" would end up at the far end.
      expect(
        tester.widget<Text>(find.text('+966 55 123 4567')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('copying puts the value on the clipboard, and says so', (
      WidgetTester tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final Map<Object?, Object?> data =
                call.arguments as Map<Object?, Object?>;
            copied = data['text'] as String?;
          }

          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        wrapWidget(
          const AppDetailRow(
            label: 'Email',
            value: 'sara@example.com',
            copyable: true,
          ),
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(copied, 'sara@example.com');
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('offers no copy unless asked to', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(const AppDetailRow(label: 'Store', value: 'Elite Store')),
      );

      expect(find.byIcon(LucideIcons.copy), findsNothing);
    });

    testWidgets('a long value wraps at twice the text size, never clips', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const String address =
          'King Abdulaziz Road, Al Narjis District, Riyadh 13327, Saudi Arabia';
      await tester.pumpWidget(
        wrapWidget(
          const AppDetailRow(
            label: 'Address',
            value: address,
            icon: LucideIcons.mapPin,
            copyable: true,
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );

      expect(tester.takeException(), isNull);
      final Text value = tester.widget<Text>(find.text(address));
      expect(value.maxLines, isNull);
      expect(value.overflow, isNot(TextOverflow.ellipsis));
    });
  });
}
