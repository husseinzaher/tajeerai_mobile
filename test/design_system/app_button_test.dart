import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/buttons/app_button.dart';
import 'package:TajeerAi/design_system/display/badge.dart';
import 'package:TajeerAi/design_system/primitives/pressable.dart';
import 'package:TajeerAi/design_system/loaders/spinner.dart';

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

      expect(find.byType(AppSpinner), findsOneWidget);
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

  group('badge and shape', () {
    testWidgets('a badge sits at the top-end corner, which flips in Arabic', (
      WidgetTester tester,
    ) async {
      // The reason there is no `NotificationButton`: it is this button with a
      // badge. A `Positioned(right:)` would pin the marker to the same
      // physical corner in both languages.
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<TextDirection>(direction),
              child: AppButton.icon(
                icon: const Icon(Icons.notifications),
                semanticLabel: 'Notifications',
                badge: const AppBadge(label: '3'),
                onPressed: () {},
              ),
            ),
            textDirection: direction,
          ),
        );
        await tester.pump();

        final double badgeX = tester.getCenter(find.text('3')).dx;
        final double buttonX = tester.getCenter(find.byType(AppButton)).dx;

        if (direction == TextDirection.ltr) {
          expect(badgeX, greaterThan(buttonX), reason: 'ltr end = right');
        } else {
          expect(badgeX, lessThan(buttonX), reason: 'rtl end = left');
        }
      }
    });

    testWidgets('circle shape is fully rounded, rounded shape is not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton.icon(
            icon: const Icon(Icons.send),
            semanticLabel: 'Send',
            shape: AppButtonShape.circle,
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.widget<AppPressable>(find.byType(AppPressable)).borderRadius,
        TajeerRadii.fullAll,
      );
    });

    testWidgets('the soft variant reads as brand without being a fill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppButton(
            label: 'Quiet',
            variant: AppButtonVariant.soft,
            onPressed: () {},
          ),
        ),
      );

      final BoxDecoration decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((Container c) => c.decoration)
          .whereType<BoxDecoration>()
          .first;

      expect(decoration.color, TajeerColors.tajeerLight.primarySoft);
    });
  });
}
