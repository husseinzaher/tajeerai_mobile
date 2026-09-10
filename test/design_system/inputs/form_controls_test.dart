import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_checkbox.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_radio.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_select.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_switch.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_text_field.dart';
import 'package:tajeerai_mobile/design_system/inputs/otp_field.dart';
import 'package:tajeerai_mobile/design_system/inputs/password_field.dart';

import '../../support/widget_harness.dart';

/// The floor a thumb needs. Every control in this family is held to it, and
/// two of them were below it before this family existed.
const double _minTarget = 44;

void main() {
  group('AppCheckbox', () {
    testWidgets('reports the opposite of what it is showing', (
      WidgetTester tester,
    ) async {
      bool? reported;
      await tester.pumpWidget(
        wrapWidget(
          AppCheckbox(
            value: false,
            label: 'Keep me signed in',
            onChanged: (bool value) => reported = value,
          ),
        ),
      );

      await tester.tap(find.text('Keep me signed in'));
      expect(reported, isTrue);
    });

    testWidgets('the label is part of the target, not decoration beside it', (
      WidgetTester tester,
    ) async {
      // The whole row is tappable. A checkbox whose 22px box is the only hit
      // area is one a thumb misses, which is what the hand-rolled version in
      // the sign-in form was working around.
      int taps = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppCheckbox(
            value: false,
            label: 'Remember me',
            onChanged: (_) => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Remember me'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(AppCheckbox)).height,
        greaterThanOrEqualTo(_minTarget),
      );
    });

    testWidgets('does not report while disabled', (WidgetTester tester) async {
      bool? reported;
      await tester.pumpWidget(
        wrapWidget(
          AppCheckbox(
            value: false,
            enabled: false,
            label: 'Off',
            onChanged: (bool value) => reported = value,
          ),
        ),
      );

      await tester.tap(find.text('Off'), warnIfMissed: false);
      expect(reported, isNull);
    });

    testWidgets('announces its state to a screen reader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppCheckbox(value: true, label: 'Subscribed', onChanged: (_) {}),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppCheckbox)),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Subscribed',
        ),
      );
    });
  });

  group('AppSwitch', () {
    testWidgets('toggles, and clears the touch-target floor', (
      WidgetTester tester,
    ) async {
      bool value = false;
      await tester.pumpWidget(
        wrapWidget(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => AppSwitch(
              value: value,
              label: 'Notifications',
              onChanged: (bool next) => setState(() => value = next),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(AppSwitch)).height,
        greaterThanOrEqualTo(_minTarget),
      );

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets(
      'the thumb travels toward the end of the line, in both directions',
      (WidgetTester tester) async {
        // The one thing a switch can get wrong in Arabic: an `Alignment` instead
        // of an `AlignmentDirectional` leaves "on" pointing the wrong way.
        for (final TextDirection direction in TextDirection.values) {
          await tester.pumpWidget(
            wrapWidget(
              KeyedSubtree(
                key: ValueKey<TextDirection>(direction),
                child: AppSwitch(value: true, onChanged: (_) {}),
              ),
              textDirection: direction,
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));

          // Measured against the *track*, not the widget: in RTL the track
          // sits at the start of the row, which is the right-hand side, so
          // comparing against the widget's centre would pass for the wrong
          // reason.
          final Finder track = find.descendant(
            of: find.byType(AppSwitch),
            matching: find.byType(AnimatedContainer),
          );
          final Finder thumb = find.descendant(
            of: find.byType(AppSwitch),
            matching: find.byType(Container),
          );
          final double thumbX = tester.getCenter(thumb.last).dx;
          final double trackX = tester.getCenter(track.first).dx;

          if (direction == TextDirection.ltr) {
            expect(thumbX, greaterThan(trackX), reason: 'ltr on = right');
          } else {
            expect(thumbX, lessThan(trackX), reason: 'rtl on = left');
          }
        }
      },
    );
  });

  group('AppRadioGroup', () {
    testWidgets('reports the option that was tapped', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        wrapWidget(
          AppRadioGroup<String>(
            value: 'a',
            options: const <AppRadioOption<String>>[
              AppRadioOption<String>(value: 'a', label: 'WhatsApp'),
              AppRadioOption<String>(value: 'b', label: 'SMS'),
            ],
            onChanged: (String value) => chosen = value,
          ),
        ),
      );

      await tester.tap(find.text('SMS'));
      expect(chosen, 'b');
    });

    testWidgets('announces exclusivity, which a row of toggles cannot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppRadioGroup<int>(
            value: 1,
            options: const <AppRadioOption<int>>[
              AppRadioOption<int>(value: 1, label: 'One'),
            ],
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('One')),
        matchesSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          isInMutuallyExclusiveGroup: true,
          label: 'One',
        ),
      );
    });

    testWidgets('a disabled option cannot be chosen', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        wrapWidget(
          AppRadioGroup<String>(
            value: 'a',
            options: const <AppRadioOption<String>>[
              AppRadioOption<String>(value: 'a', label: 'Available'),
              AppRadioOption<String>(
                value: 'b',
                label: 'Not connected',
                enabled: false,
              ),
            ],
            onChanged: (String value) => chosen = value,
          ),
        ),
      );

      await tester.tap(find.text('Not connected'), warnIfMissed: false);
      expect(chosen, isNull);
    });
  });

  group('AppSelect', () {
    Widget subject({String? value, ValueChanged<String>? onChanged}) =>
        wrapWidget(
          AppSelect<String>(
            label: 'Channel',
            placeholder: 'Choose one',
            value: value,
            options: const <AppSelectOption<String>>[
              AppSelectOption<String>(value: 'wa', label: 'WhatsApp'),
              AppSelectOption<String>(value: 'sms', label: 'SMS'),
            ],
            onChanged: onChanged ?? (_) {},
          ),
        );

    testWidgets('shows the placeholder until something is chosen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      expect(find.text('Choose one'), findsOneWidget);

      await tester.pumpWidget(subject(value: 'wa'));
      expect(find.text('Choose one'), findsNothing);
      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('opens a sheet and reports the choice', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(subject(onChanged: (String v) => chosen = v));

      await tester.tap(find.text('Choose one'));
      await tester.pumpAndSettle();

      // Both options are on screen: this is a sheet, not a popover clipped to
      // the control's width.
      expect(find.text('SMS'), findsOneWidget);
      await tester.tap(find.text('SMS'));
      await tester.pumpAndSettle();

      expect(chosen, 'sms');
    });

    testWidgets('a dismissed sheet reports nothing', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(subject(onChanged: (String v) => chosen = v));

      await tester.tap(find.text('Choose one'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('SMS'))).pop();
      await tester.pumpAndSettle();

      expect(chosen, isNull);
    });
  });

  group('AppPasswordField', () {
    testWidgets('the toggle flips both the obscuring and its own label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(const AppPasswordField(label: 'Password')),
      );

      expect(
        tester.widget<AppTextField>(find.byType(AppTextField)).obscureText,
        isTrue,
      );
      expect(find.bySemanticsLabel('Show password'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Show password'));
      await tester.pump();

      expect(
        tester.widget<AppTextField>(find.byType(AppTextField)).obscureText,
        isFalse,
      );
      // The label has to change with the state: announcing "show password" on
      // a field that is already showing is worse than announcing nothing.
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    });

    testWidgets('the reveal control is a real target, not a glyph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const AppPasswordField()));

      expect(
        tester.getSize(find.bySemanticsLabel('Show password')).height,
        greaterThanOrEqualTo(_minTarget),
      );
    });
  });

  group('AppOtpField', () {
    testWidgets('renders one box per digit and fills them in order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const AppOtpField(length: 4)));

      await tester.enterText(find.byType(TextField), '48');
      await tester.pump();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('fires onCompleted exactly when the last digit lands', (
      WidgetTester tester,
    ) async {
      final List<String> completed = <String>[];
      await tester.pumpWidget(
        wrapWidget(AppOtpField(length: 4, onCompleted: completed.add)),
      );

      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(completed, isEmpty);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      expect(completed, <String>['1234']);
    });

    testWidgets('keeps the digits left-to-right inside an Arabic screen', (
      WidgetTester tester,
    ) async {
      // A code is a sequence, not a sentence. Mirroring the boxes would ask
      // somebody to type it backwards while looking entirely correct.
      await tester.pumpWidget(
        wrapWidget(
          const AppOtpField(length: 3),
          textDirection: TextDirection.rtl,
        ),
      );

      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();

      expect(
        tester.getCenter(find.text('1')).dx,
        lessThan(tester.getCenter(find.text('3')).dx),
      );
    });

    testWidgets('accepts only digits', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWidget(const AppOtpField(length: 4)));

      await tester.enterText(find.byType(TextField), '1a2b');
      await tester.pump();

      expect(find.text('a'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('the family shares one border', () {
    testWidgets('an invalid control is outlined in dangerDefault', (
      WidgetTester tester,
    ) async {
      // Not `dangerBorder`: that is a decorative hairline around a wash and is
      // ~1.5:1 on it. A control boundary is a different contrast problem.
      await tester.pumpWidget(
        wrapWidget(const AppTextField(errorText: 'Required')),
      );

      final Iterable<Container> boxes = tester
          .widgetList<Container>(find.byType(Container))
          .where((Container c) => c.decoration is BoxDecoration);
      final Iterable<Color?> borders = boxes.map(
        (Container c) => (c.decoration! as BoxDecoration).border?.top.color,
      );

      expect(borders, contains(TajeerColors.tajeerLight.dangerDefault));
    });
  });
}
