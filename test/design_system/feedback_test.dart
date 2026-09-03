import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/app/theme/colors.dart';
import 'package:tajeerai_mobile/design_system/feedback/empty_state.dart';
import 'package:tajeerai_mobile/design_system/feedback/error_state.dart';
import 'package:tajeerai_mobile/design_system/loaders/skeleton.dart';
import 'package:tajeerai_mobile/design_system/loaders/spinner.dart';

import '../support/widget_harness.dart';

void main() {
  group('EmptyState', () {
    testWidgets('shows a title, description and icon', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const EmptyState(
            title: 'No conversations yet',
            description: 'New conversations will appear here.',
            icon: LucideIcons.messageSquare,
          ),
        ),
      );

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('New conversations will appear here.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.messageSquare), findsOneWidget);
    });

    testWidgets('offers an action when one is given', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrapWidget(
          EmptyState(
            title: 'Nothing here',
            actionLabel: 'Refresh',
            onAction: () => taps += 1,
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('omits the action when none is given', (tester) async {
      await tester.pumpWidget(
        wrapWidget(const EmptyState(title: 'Nothing here')),
      );

      expect(find.text('Refresh'), findsNothing);
    });

    testWidgets('renders in both appearances', (tester) async {
      await pumpInBothThemes(tester, const EmptyState(title: 'Nothing here'), (
        tester,
        brightness,
      ) async {
        expect(find.text('Nothing here'), findsOneWidget);
      });
    });
  });

  group('ErrorState', () {
    testWidgets('shows the message it was given', (tester) async {
      await tester.pumpWidget(
        wrapWidget(const ErrorState(message: 'The list could not be read.')),
      );

      expect(find.text('The list could not be read.'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('offers a retry', (tester) async {
      var retries = 0;

      await tester.pumpWidget(
        wrapWidget(ErrorState(message: 'Boom.', onRetry: () => retries += 1)),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retries, 1);
    });
  });

  group('InlineError', () {
    testWidgets('renders on the destructive token', (tester) async {
      await tester.pumpWidget(
        wrapWidget(const InlineError(message: 'Check your details.')),
      );

      final text = tester.widget<Text>(find.text('Check your details.'));

      expect(text.style!.color, TajeerColors.light.destructive);
    });

    testWidgets('uses the dark destructive token in dark mode', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const InlineError(message: 'Check your details.'),
          brightness: Brightness.dark,
        ),
      );

      final text = tester.widget<Text>(find.text('Check your details.'));

      expect(text.style!.color, TajeerColors.dark.destructive);
    });
  });

  group('StatusBanner', () {
    testWidgets('renders a warning tone', (tester) async {
      await tester.pumpWidget(
        wrapWidget(const StatusBanner(message: 'Reconnecting…')),
      );

      expect(find.text('Reconnecting…'), findsOneWidget);
    });
  });

  group('loaders', () {
    testWidgets('the spinner announces itself to a screen reader', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const Spinner()));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);

      // Let the repeating animation settle so the test can finish.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the skeleton is hidden from screen readers', (tester) async {
      await tester.pumpWidget(wrapWidget(const Skeleton(width: 100)));
      await tester.pump();

      // A placeholder that reads out as an unlabelled box is noise.
      expect(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
