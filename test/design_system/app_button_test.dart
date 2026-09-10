import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/loaders/spinner.dart';

import '../support/widget_harness.dart';

/// The decoration of the button's own container.
BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(AppButton),
          matching: find.byType(Container),
        )
        .first,
  );

  return container.decoration! as BoxDecoration;
}

void main() {
  group('rendering', () {
    testWidgets('shows its label', (tester) async {
      await tester.pumpWidget(
        wrapWidget(AppButton(label: 'Sign in', onPressed: () {})),
      );

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('renders in both appearances', (tester) async {
      await pumpInBothThemes(
        tester,
        AppButton(label: 'Sign in', onPressed: () {}),
        (tester, brightness) async {
          expect(find.text('Sign in'), findsOneWidget);

          final expected = brightness == Brightness.dark
              ? TajeerColors.tajeerDark.primary
              : TajeerColors.tajeerLight.primary;

          expect(_decorationOf(tester).color, expected);
        },
      );
    });

    testWidgets('uses the semantic token, never a hardcoded colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton(
            label: 'Delete',
            variant: AppButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );

      expect(
        _decorationOf(tester).color,
        TajeerColors.tajeerLight.dangerDefault,
      );
    });

    testWidgets('outline shows the surface behind it', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.outline,
            onPressed: () {},
          ),
        ),
      );

      // Deliberately transparent: it takes the colour of whatever card or
      // sidebar it was dropped onto.
      expect(_decorationOf(tester).color, Colors.transparent);
      expect(_decorationOf(tester).border, isNotNull);
    });
  });

  group('interaction', () {
    testWidgets('fires its callback on tap', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrapWidget(AppButton(label: 'Send', onPressed: () => taps += 1)),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('does not fire when disabled', (tester) async {
      await tester.pumpWidget(wrapWidget(const AppButton(label: 'Send')));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      // No callback to fire; asserted by the absence of an exception and the
      // dimmed opacity below.
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );

      expect(opacity.opacity, 0.5);
    });

    testWidgets('does not fire while loading', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrapWidget(
          AppButton(label: 'Send', loading: true, onPressed: () => taps += 1),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(taps, 0);
    });
  });

  group('loading state', () {
    testWidgets('swaps the leading slot for a spinner, keeping the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton(
            label: 'Sign in',
            loading: true,
            leading: const Icon(Icons.add),
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(Spinner), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);

      // The label stays put so the button does not change width mid-press.
      expect(find.text('Sign in'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('an icon button carries its semantic label', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton.icon(
            icon: const Icon(Icons.send),
            semanticLabel: 'Send message',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    });

    testWidgets('a labelled button is announced as a button', (tester) async {
      await tester.pumpWidget(
        wrapWidget(AppButton(label: 'Sign in', onPressed: () {})),
      );

      final semantics = tester.getSemantics(find.byType(AppButton));

      expect(semantics.label, contains('Sign in'));
    });
  });

  group('sizes', () {
    testWidgets('each size meets its minimum height', (tester) async {
      const expected = <AppButtonSize, double>{
        AppButtonSize.small: 32,
        AppButtonSize.medium: 36,
        AppButtonSize.large: 40,
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          wrapWidget(AppButton(label: 'X', size: entry.key, onPressed: () {})),
        );

        final box = tester.getSize(find.byType(AppButton));

        expect(
          box.height,
          greaterThanOrEqualTo(entry.value),
          reason: '${entry.key} should be at least ${entry.value}px tall',
        );
      }
    });
  });
}
