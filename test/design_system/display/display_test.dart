import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/display/avatar.dart';
import 'package:TajeerAi/design_system/display/avatar_group.dart';
import 'package:TajeerAi/design_system/display/badge.dart';
import 'package:TajeerAi/design_system/display/chip.dart';
import 'package:TajeerAi/design_system/display/labelled_separator.dart';
import 'package:TajeerAi/design_system/display/list_item.dart';
import 'package:TajeerAi/design_system/display/list_section.dart';
import 'package:TajeerAi/design_system/display/segmented_control.dart';
import 'package:TajeerAi/design_system/display/separator.dart';
import 'package:TajeerAi/design_system/display/status_dot.dart';
import 'package:TajeerAi/design_system/display/tabs.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppBadge', () {
    testWidgets('a count over its ceiling stops being a number', (
      WidgetTester tester,
    ) async {
      // Four digits is not a count anybody reads, it is a shape that breaks
      // the row it rides on.
      await tester.pumpWidget(wrapWidget(AppBadge.count(1284)));
      expect(find.text('99+'), findsOneWidget);

      await tester.pumpWidget(wrapWidget(AppBadge.count(7)));
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a single-digit count is a circle, at every text size', (
      WidgetTester tester,
    ) async {
      // The floor used to be a fixed 20 wide, and the typeface's leading made
      // the pill 26 tall — a capsule standing on end. The floor is the badge's
      // own height now, so it has to hold as the text grows.
      for (final double scale in <double>[1, 1.3, 2]) {
        await tester.pumpWidget(
          wrapWidget(
            UnconstrainedBox(child: AppBadge.count(3)),
            textScaler: TextScaler.linear(scale),
          ),
        );
        final Size one = tester.getSize(find.byType(AppBadge));
        expect(
          one.width,
          moreOrLessEquals(one.height, epsilon: 0.5),
          reason: 'one digit at text scale $scale',
        );

        await tester.pumpWidget(
          wrapWidget(
            UnconstrainedBox(child: AppBadge.count(12)),
            textScaler: TextScaler.linear(scale),
          ),
        );
        final Size two = tester.getSize(find.byType(AppBadge));
        expect(
          two.width,
          greaterThanOrEqualTo(two.height),
          reason: 'two digits at text scale $scale',
        );
      }
    });

    testWidgets('a dot carries no text at all', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWidget(const AppBadge.dot()));
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(AppBadge)).width, 10);
    });

    testWidgets('every variant renders in both appearances', (
      WidgetTester tester,
    ) async {
      for (final AppBadgeVariant variant in AppBadgeVariant.values) {
        await pumpInBothThemes(
          tester,
          AppBadge(label: variant.name, variant: variant),
          (WidgetTester tester, Brightness brightness) async {
            expect(tester.takeException(), isNull, reason: variant.name);
          },
        );
      }
    });
  });

  group('at twice the text size, nothing is pushed off a phone', () {
    // Each of these overflowed the first time the showcase smoke test laid a
    // section out at a phone's real width. The SizedBox is what gives them
    // that width: wrapWidget's size only changes what MediaQuery reports.
    Widget atPhoneWidth(Widget child, {double scale = 2}) => wrapWidget(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: 360, child: child),
      ),
      textScaler: TextScaler.linear(scale),
    );

    testWidgets('a list row moves its time under the title, past the clamp', (
      WidgetTester tester,
    ) async {
      const AppListItem item = AppListItem(
        leading: AppAvatar(name: 'سارة أحمد'),
        title: Text('سارة أحمد'),
        meta: Text('10:24'),
        subtitle: Text('هل الطلب جاهز للاستلام اليوم؟'),
        trailing: AppBadge(label: '3'),
      );

      for (final double scale in <double>[
        1,
        TajeerTypography.controlMaxScale,
      ]) {
        await tester.pumpWidget(atPhoneWidth(item, scale: scale));
        expect(
          tester.getTopLeft(find.text('10:24')).dy,
          moreOrLessEquals(tester.getTopLeft(find.text('سارة أحمد')).dy),
          reason: 'at text scale $scale the time shares the title line',
        );
      }

      await tester.pumpWidget(atPhoneWidth(item));
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('10:24')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('سارة أحمد')).dy),
        reason: 'at 2× the time sits under the title, and the row grows',
      );
    });

    testWidgets('a labelled separator wraps its word and keeps both rules', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        atPhoneWidth(
          const AppLabelledSeparator(label: 'أو تابع باستخدام حساب آخر لديك'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Divider), findsNWidgets(2));
      for (final Finder rule in <Finder>[
        find.byType(Divider).first,
        find.byType(Divider).last,
      ]) {
        expect(
          tester.getSize(rule).width,
          greaterThanOrEqualTo(TajeerSpacing.lg),
        );
      }
    });

    testWidgets('a segmented control shares the row instead of leaving it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        atPhoneWidth(
          AppSegmentedControl<int>(
            value: 0,
            onChanged: (int value) {},
            options: const <int, String>{
              0: 'Light appearance',
              1: 'Dark appearance',
              2: 'Follow the system',
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);

      // With room to spare it is as wide as its labels, not as wide as the
      // row: sharing is for when there is not enough. The Align loosens the
      // phone's width, which would otherwise force the control to fill it.
      await tester.pumpWidget(
        atPhoneWidth(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppSegmentedControl<int>(
              value: 0,
              onChanged: (int value) {},
              options: const <int, String>{0: 'A', 1: 'B'},
            ),
          ),
          scale: 1,
        ),
      );
      expect(
        tester.getSize(find.byType(AppSegmentedControl<int>)).width,
        lessThan(180),
      );
    });
  });

  group('AppStatusDot and presence', () {
    testWidgets('an unknown presence draws nothing', (
      WidgetTester tester,
    ) async {
      // Unknown is not offline. A grey dot is a confident answer to a question
      // the app cannot answer.
      await tester.pumpWidget(
        wrapWidget(const AppPresenceDot(presence: AppPresence.unknown)),
      );
      expect(find.byType(AppStatusDot), findsNothing);
    });

    testWidgets('each known presence has its own colour', (
      WidgetTester tester,
    ) async {
      final Set<Color> seen = <Color>{};
      for (final AppPresence presence in <AppPresence>[
        AppPresence.online,
        AppPresence.away,
        AppPresence.busy,
        AppPresence.offline,
      ]) {
        await tester.pumpWidget(wrapWidget(AppPresenceDot(presence: presence)));
        final BoxDecoration decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: find.byType(AppStatusDot),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        seen.add(decoration.color!);
      }
      expect(seen, hasLength(4));
    });
  });

  group('AppAvatar', () {
    testWidgets('initials work on Arabic and on one-word names', (
      WidgetTester tester,
    ) async {
      expect(AppAvatar.initialsOf('سارة أحمد'), 'سأ');
      expect(AppAvatar.initialsOf('Nour'), 'NO');
      expect(AppAvatar.initialsOf('   '), '?');
      expect(AppAvatar.initialsOf('خالد عبدالله السالم'), 'خا');
    });

    testWidgets('a presence marker lands on the end side, and flips', (
      WidgetTester tester,
    ) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<TextDirection>(direction),
              child: const AppAvatar(
                name: 'سارة',
                presence: AppPresence.online,
              ),
            ),
            textDirection: direction,
          ),
        );
        await tester.pump();

        final double dot = tester.getCenter(find.byType(AppStatusDot)).dx;
        final double avatar = tester.getCenter(find.byType(AppAvatar)).dx;

        if (direction == TextDirection.ltr) {
          expect(dot, greaterThan(avatar), reason: 'ltr end = right');
        } else {
          expect(dot, lessThan(avatar), reason: 'rtl end = left');
        }
      }
    });

    testWidgets('a badge wins over a presence dot', (
      WidgetTester tester,
    ) async {
      // A channel is the more specific fact, and two markers on one corner is
      // two markers on one corner.
      await tester.pumpWidget(
        wrapWidget(
          const AppAvatar(
            name: 'سارة',
            presence: AppPresence.online,
            badge: AppBadge.dot(),
          ),
        ),
      );

      expect(find.byType(AppBadge), findsOneWidget);
      expect(find.byType(AppStatusDot), findsNothing);
    });
  });

  group('AppAvatarGroup', () {
    testWidgets('shows the count of whoever did not fit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppAvatarGroup(
            names: <String>['أحمد', 'سارة', 'خالد', 'نورة', 'محمد'],
            max: 3,
          ),
        ),
      );

      expect(find.byType(AppAvatar), findsNWidgets(3));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('has a definite width, and the ring is part of it', (
      WidgetTester tester,
    ) async {
      // Every child is positioned, so without an explicit width the group
      // took whatever its parent handed it — the full test surface here. And
      // spacing by the bare avatar size ignored the 2px cutout, which is what
      // made the faces crowd each other in the showcase capture.
      const double size = 32;
      const double diameter = size + 4;
      const double step = diameter - size * 0.3;

      await tester.pumpWidget(
        wrapWidget(
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppAvatarGroup(
              names: <String>['أحمد', 'سارة', 'خالد', 'نورة', 'محمد'],
              max: 3,
              size: size,
            ),
          ),
        ),
      );

      // Three faces and a count: four slots.
      expect(
        tester.getSize(find.byType(AppAvatarGroup)).width,
        moreOrLessEquals(step * 3 + diameter),
      );

      final List<double> centres =
          tester
              .widgetList<AppAvatar>(find.byType(AppAvatar))
              .map(
                (AppAvatar avatar) =>
                    tester.getCenter(find.byWidget(avatar)).dx,
              )
              .toList()
            ..sort();
      for (int i = 1; i < centres.length; i++) {
        expect(
          centres[i] - centres[i - 1],
          moreOrLessEquals(step),
          reason: 'faces ${i - 1} and $i are not one step apart',
        );
      }
    });

    testWidgets('the count is sized like the initials beside it', (
      WidgetTester tester,
    ) async {
      // Two texts in one row of circles, one sizing rule. At the default 32px
      // a fixed type step happened to match; at 80px it did not, and the "+2"
      // looked lost. Checked at a size where the two rules would disagree.
      await tester.pumpWidget(
        wrapWidget(
          const Align(
            child: AppAvatarGroup(
              names: <String>['أحمد', 'سارة', 'خالد', 'نورة', 'محمد'],
              max: 3,
              size: 80,
            ),
          ),
        ),
      );

      final double? count = tester
          .widget<Text>(find.text('+2'))
          .style
          ?.fontSize;
      final double? initials = tester
          .widget<Text>(find.text(AppAvatar.initialsOf('أحمد')))
          .style
          ?.fontSize;

      expect(count, isNotNull);
      expect(count, initials);
    });

    testWidgets('an empty group takes no room', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(const Align(child: AppAvatarGroup(names: <String>[]))),
      );
      expect(tester.getSize(find.byType(AppAvatarGroup)), Size.zero);
    });

    testWidgets('no count when everybody fits', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(const AppAvatarGroup(names: <String>['أحمد', 'سارة'])),
      );

      expect(find.byType(AppAvatar), findsNWidgets(2));
      expect(find.textContaining('+'), findsNothing);
    });
  });

  group('AppChip', () {
    testWidgets('removing and selecting are different taps', (
      WidgetTester tester,
    ) async {
      // The whole reason the remove affordance has its own hit target: on a
      // filter row, one of these is destructive and the other is not.
      int selected = 0;
      int removed = 0;

      await tester.pumpWidget(
        wrapWidget(
          AppChip(
            label: 'غير مقروءة',
            onTap: () => selected++,
            onRemove: () => removed++,
          ),
        ),
      );

      await tester.tap(find.byType(AppChip));
      expect(selected, 1);
      expect(removed, 0);

      await tester.tap(find.bySemanticsLabel('Dismiss'));
      expect(removed, 1);
      expect(selected, 1, reason: 'removing must not also select');
    });

    testWidgets('selected reads as selected, not just as coloured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(AppChip(label: 'الكل', selected: true, onTap: () {})),
      );

      // Found by label rather than by type: `getSemantics` on a widget walks
      // up to the nearest node, which here is the pressable's, not the chip's
      // own container.
      // `isSelected` is a Tristate, not a bool, and deliberately so: a control
      // that cannot be selected at all is a different fact from one that is
      // selectable and currently is not.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('الكل'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    });
  });

  group('AppListItem', () {
    testWidgets('emphasis changes the title weight, not the caller', (
      WidgetTester tester,
    ) async {
      // A flag rather than every list styling its own unread state, which is
      // how two lists end up disagreeing about what unread looks like.
      await tester.pumpWidget(
        wrapWidget(
          const Column(
            children: <Widget>[
              AppListItem(title: Text('read'), emphasised: false),
              AppListItem(title: Text('unread'), emphasised: true),
            ],
          ),
        ),
      );

      FontWeight weightOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontWeight!;

      // The style is merged by a DefaultTextStyle above, so read it there.
      final TextStyle read = DefaultTextStyle.of(
        tester.element(find.text('read')),
      ).style;
      final TextStyle unread = DefaultTextStyle.of(
        tester.element(find.text('unread')),
      ).style;

      expect(unread.fontWeight, FontWeight.w700);
      expect(read.fontWeight, isNot(FontWeight.w700));
      expect(weightOf, isNotNull);
    });

    testWidgets('a selected row is marked on the start edge, which flips', (
      WidgetTester tester,
    ) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<TextDirection>(direction),
              child: const AppListItem(title: Text('row'), selected: true),
            ),
            textDirection: direction,
          ),
        );
        await tester.pump();

        final BoxDecoration decoration =
            tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: find.byType(AppListItem),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        final BorderDirectional border =
            decoration.border! as BorderDirectional;

        expect(border.start.width, 3);
        expect(
          border.start.color,
          TajeerColors.tajeerLight.primary,
          reason: direction.name,
        );
      }
    });

    testWidgets('taps and long-presses report separately', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int longPresses = 0;

      await tester.pumpWidget(
        wrapWidget(
          AppListItem(
            title: const Text('row'),
            onTap: () => taps++,
            onLongPress: () => longPresses++,
          ),
        ),
      );

      await tester.tap(find.text('row'));
      expect(taps, 1);

      await tester.longPress(find.text('row'));
      expect(longPresses, 1);
      expect(taps, 1);
    });
  });

  group('AppListSection', () {
    testWidgets('separates rows without a trailing rule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppListSection(
            title: 'الإعدادات',
            children: <Widget>[
              AppListItem(title: Text('a')),
              AppListItem(title: Text('b')),
              AppListItem(title: Text('c')),
            ],
          ),
        ),
      );

      // Three rows, two rules between them. A trailing separator inside a
      // bordered group draws a line on top of the group's own edge.
      expect(find.byType(AppListItem), findsNWidgets(3));
      expect(find.byType(AppSeparator), findsNWidgets(2));
    });
  });

  group('AppTabs and AppSegmentedControl are not the same control', () {
    testWidgets('tabs announce selection and report an index', (
      WidgetTester tester,
    ) async {
      int chosen = -1;
      await tester.pumpWidget(
        wrapWidget(
          AppTabs(
            index: 0,
            tabs: const <AppTab>[
              AppTab(label: 'الكل'),
              AppTab(label: 'غير مقروءة'),
            ],
            onChanged: (int i) => chosen = i,
          ),
        ),
      );

      await tester.tap(find.text('غير مقروءة'));
      expect(chosen, 1);
    });

    testWidgets('a segmented control announces exclusivity; tabs do not', (
      WidgetTester tester,
    ) async {
      // The whole reason these are two widgets. Tabs reveal a panel; a
      // segmented control picks a value, and only one of those is a form
      // control a screen reader should treat as mutually exclusive.
      await tester.pumpWidget(
        wrapWidget(
          AppSegmentedControl<String>(
            value: 'a',
            options: const <String, String>{'a': 'الكل', 'b': 'مهمة'},
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester
            .getSemantics(find.text('الكل'))
            .getSemanticsData()
            .flagsCollection
            .isInMutuallyExclusiveGroup,
        isTrue,
      );

      await tester.pumpWidget(
        wrapWidget(
          AppTabs(
            index: 0,
            tabs: const <AppTab>[AppTab(label: 'tab')],
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester
            .getSemantics(find.text('tab'))
            .getSemanticsData()
            .flagsCollection
            .isInMutuallyExclusiveGroup,
        isFalse,
      );
    });

    testWidgets('a segmented control reports the value that was picked', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await tester.pumpWidget(
        wrapWidget(
          AppSegmentedControl<String>(
            value: 'a',
            options: const <String, String>{'a': 'Light', 'b': 'Dark'},
            onChanged: (String v) => chosen = v,
          ),
        ),
      );

      await tester.tap(find.text('Dark'));
      expect(chosen, 'b');
    });
  });
}
