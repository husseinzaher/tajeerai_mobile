import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/display/avatar.dart';
import 'package:tajeerai_mobile/design_system/display/avatar_group.dart';
import 'package:tajeerai_mobile/design_system/display/badge.dart';
import 'package:tajeerai_mobile/design_system/display/chip.dart';
import 'package:tajeerai_mobile/design_system/display/list_item.dart';
import 'package:tajeerai_mobile/design_system/display/list_section.dart';
import 'package:tajeerai_mobile/design_system/display/segmented_control.dart';
import 'package:tajeerai_mobile/design_system/display/separator.dart';
import 'package:tajeerai_mobile/design_system/display/status_dot.dart';
import 'package:tajeerai_mobile/design_system/display/tabs.dart';

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
