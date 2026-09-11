import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/display/avatar.dart';
import 'package:tajeerai_mobile/design_system/display/badge.dart';
import 'package:tajeerai_mobile/design_system/inputs/search_field.dart';
import 'package:tajeerai_mobile/design_system/layouts/app_scaffold.dart';
import 'package:tajeerai_mobile/design_system/shell/app_shell.dart';
import 'package:tajeerai_mobile/design_system/shell/bottom_navigation.dart';
import 'package:tajeerai_mobile/design_system/shell/navigation_destination.dart';
import 'package:tajeerai_mobile/design_system/shell/navigation_drawer.dart';
import 'package:tajeerai_mobile/design_system/shell/shell_scope.dart';
import 'package:tajeerai_mobile/design_system/shell/toolbar.dart';

import '../../support/widget_harness.dart';

/// Long enough for a drawer to finish sliding. Never `pumpAndSettle`: nothing
/// here spins, but the habit is what keeps the suites that do from hanging.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A toolbar where it lives: in a scaffold, not loose in a page.
Widget _page(PreferredSizeWidget toolbar) =>
    AppScaffold(toolbar: toolbar, body: const SizedBox.shrink());

/// Found by label: `getSemantics` on a widget walks up to the nearest node,
/// which for these rows is the pressable's rather than the row's container.
Tristate _selected(WidgetTester tester, String label) => tester
    .getSemantics(find.bySemanticsLabel(label))
    .getSemanticsData()
    .flagsCollection
    .isSelected;

const List<AppNavDestination> _tabs = <AppNavDestination>[
  AppNavDestination(
    id: 'inbox',
    label: 'Inbox',
    icon: LucideIcons.messagesSquare,
    badgeCount: 3,
  ),
  AppNavDestination(
    id: 'customers',
    label: 'Customers',
    icon: LucideIcons.users,
  ),
  AppNavDestination(
    id: 'orders',
    label: 'Orders',
    icon: LucideIcons.shoppingBag,
  ),
  AppNavDestination(id: 'more', label: 'More', icon: LucideIcons.ellipsis),
];

void main() {
  group('AppToolbar', () {
    testWidgets('the back chevron points toward the start of the line', (
      WidgetTester tester,
    ) async {
      await pumpInBothDirections(
        tester,
        _page(AppToolbar(title: 'Order', showBack: true, onBack: () {})),
        (WidgetTester tester, TextDirection direction) async {
          final bool rtl = direction == TextDirection.rtl;
          final Finder chevron = find.byIcon(
            rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          );

          expect(chevron, findsOneWidget);
          expect(
            find.byIcon(
              rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
            ),
            findsNothing,
          );

          // Where it sits, not only which glyph: at the start edge.
          final double middle = tester.getCenter(find.byType(AppToolbar)).dx;
          expect(
            tester.getCenter(chevron).dx,
            rtl ? greaterThan(middle) : lessThan(middle),
          );
        },
      );
    });

    testWidgets('back leaves the route when nobody says otherwise', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const Text('Home')));
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    _page(const AppToolbar(title: 'Order', showBack: true)),
              ),
            ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Order'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Order'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('the menu button appears only inside a shell with a drawer', (
      WidgetTester tester,
    ) async {
      int opened = 0;

      await tester.pumpWidget(
        wrapWidget(_page(const AppToolbar(title: 'Inbox'))),
      );
      expect(find.byIcon(LucideIcons.menu), findsNothing);

      // A shell with nothing to open offers nothing to press.
      await tester.pumpWidget(
        wrapWidget(
          AppShellScope(
            hasDrawer: false,
            openDrawer: () => opened++,
            child: _page(const AppToolbar(title: 'Inbox')),
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.menu), findsNothing);

      await tester.pumpWidget(
        wrapWidget(
          AppShellScope(
            hasDrawer: true,
            openDrawer: () => opened++,
            child: _page(const AppToolbar(title: 'Inbox')),
          ),
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.menu));
      expect(opened, 1);

      // A way back outranks the menu: a pushed screen is not a top-level one.
      await tester.pumpWidget(
        wrapWidget(
          AppShellScope(
            hasDrawer: true,
            openDrawer: () => opened++,
            child: _page(const AppToolbar(title: 'Order', showBack: true)),
          ),
        ),
      );
      expect(find.byIcon(LucideIcons.menu), findsNothing);
      expect(find.byIcon(LucideIcons.chevronLeft), findsOneWidget);
    });

    testWidgets('search mode swaps the title for a focused field', (
      WidgetTester tester,
    ) async {
      final TextEditingController query = TextEditingController();
      addTearDown(query.dispose);
      final List<String> typed = <String>[];
      int closed = 0;

      await tester.pumpWidget(
        wrapWidget(
          _page(
            AppToolbar(
              title: 'Customers',
              mode: AppToolbarMode.search,
              searchController: query,
              searchHint: 'Find a customer',
              onSearchChanged: typed.add,
              onSearchClose: () => closed++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppSearchField), findsOneWidget);
      expect(find.text('Customers'), findsNothing);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.enterText(find.byType(EditableText), 'Sara');
      expect(typed.last, 'Sara');

      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      expect(closed, 1);
    });

    testWidgets('search mode without a controller is a mistake, and says so', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(_page(const AppToolbar(mode: AppToolbarMode.search))),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('selection mode counts the selection on a tinted bar', (
      WidgetTester tester,
    ) async {
      int closed = 0;
      int archived = 0;

      Widget toolbar() => _page(
        AppToolbar(
          title: 'Inbox',
          mode: AppToolbarMode.selection,
          selectionCount: 3,
          onSelectionClose: () => closed++,
          selectionActions: <Widget>[
            AppButton.icon(
              icon: const Icon(LucideIcons.archive),
              semanticLabel: 'Archive',
              onPressed: () => archived++,
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapWidget(toolbar()));

      expect(find.text('3 selected'), findsOneWidget);
      expect(find.text('Inbox'), findsNothing);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        tester.element(find.byType(AppToolbar)).colors.primarySoft,
      );

      await tester.tap(find.byIcon(LucideIcons.archive));
      await tester.tap(find.byIcon(LucideIcons.x));
      expect(archived, 1);
      expect(closed, 1);

      await tester.pumpWidget(
        wrapWidget(
          toolbar(),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pump();
      expect(find.text('تم تحديد 3'), findsOneWidget);
    });

    testWidgets('the title is a header, held to the control ceiling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          _page(
            const AppToolbar(
              title: 'A title long enough to need its ellipsis on a phone',
              subtitle: '#1042',
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );

      // A fixed-height bar cannot grow, so its text must stop growing first —
      // and must not clip at the point where it stops.
      expect(tester.takeException(), isNull);
      final Element title = tester.element(
        find.text('A title long enough to need its ellipsis on a phone'),
      );
      expect(MediaQuery.textScalerOf(title).scale(10), lessThanOrEqualTo(13));

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'A title long enough to need its ellipsis on a phone',
          ),
        ),
        isSemantics(isHeader: true),
      );
    });

    testWidgets('the conversation preset is the same toolbar with a person', (
      WidgetTester tester,
    ) async {
      int backs = 0;
      int titleTaps = 0;

      await tester.pumpWidget(
        wrapWidget(
          _page(
            AppToolbar.conversation(
              title: 'Sara Ahmed',
              subtitle: 'Online',
              onBack: () => backs++,
              onTitleTap: () => titleTaps++,
            ),
          ),
        ),
      );

      expect(find.byType(AppToolbar), findsOneWidget);
      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      await tester.tap(find.text('Sara Ahmed'));
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      expect(titleTaps, 1);
      expect(backs, 1);
    });
  });

  group('typeface', () {
    // `AppBar` replaces the inherited text style with its theme's title style.
    // When that style came from a text theme without the family, everything in
    // the toolbar fell back to the platform font — the goldens showed it; no
    // assertion did.
    testWidgets('text inside the toolbar is set in the product typeface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          _page(const AppToolbar(title: 'Inbox', subtitle: 'Elite Store')),
        ),
      );

      String? family(String text) {
        final Finder finder = find.text(text);
        return DefaultTextStyle.of(tester.element(finder)).style
            .merge(tester.widget<Text>(finder).style)
            .fontFamily;
      }

      expect(family('Inbox'), TajeerTypography.sansFamily);
      expect(family('Elite Store'), TajeerTypography.sansFamily);
    });
  });

  group('AppNavigationDrawer', () {
    AppNavigationDrawer drawer({
      ValueChanged<String>? onSelect,
      VoidCallback? onSignOut,
    }) => AppNavigationDrawer(
      profile: const AppDrawerProfile(
        name: 'Ada Lovelace',
        subtitle: 'Elite Store',
      ),
      selectedId: 'orders',
      onSelect: onSelect ?? (String id) {},
      groups: const <AppNavGroup>[
        AppNavGroup(
          destinations: <AppNavDestination>[
            AppNavDestination(
              id: 'inbox',
              label: 'Inbox',
              icon: LucideIcons.messagesSquare,
            ),
            AppNavDestination(
              id: 'orders',
              label: 'Orders',
              icon: LucideIcons.shoppingBag,
              badgeCount: 12,
            ),
          ],
        ),
        AppNavGroup(
          label: 'Growth',
          destinations: <AppNavDestination>[
            AppNavDestination(
              id: 'reports',
              label: 'Reports',
              icon: LucideIcons.chartColumn,
            ),
          ],
        ),
      ],
      footerActions: <AppDrawerAction>[
        AppDrawerAction(
          label: 'Sign out',
          icon: LucideIcons.logOut,
          destructive: true,
          onPressed: onSignOut ?? () {},
        ),
      ],
    );

    /// On its own, the way the showcase draws it: a panel with no drawer
    /// around it to close.
    Widget panel(AppNavigationDrawer drawer) => wrapWidget(
      Align(alignment: AlignmentDirectional.centerStart, child: drawer),
    );

    /// Inside a shell, opened from the toolbar the way a member opens it.
    Widget shell(AppNavigationDrawer drawer) => AppShell(
      drawer: drawer,
      body: _page(const AppToolbar(title: 'Inbox')),
    );

    testWidgets('shows who is signed in, and in which store', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(panel(drawer()));

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Elite Store'), findsOneWidget);
      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('Growth'), findsOneWidget);
    });

    testWidgets('the current destination reads as selected, not just tinted', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(panel(drawer()));

      // The count is part of what a screen reader hears, not only a bubble.
      expect(_selected(tester, 'Orders, 12'), Tristate.isTrue);
      expect(_selected(tester, 'Inbox'), Tristate.isFalse);
      expect(find.byType(AppBadge), findsOneWidget);

      FontWeight? weight(String label) =>
          tester.widget<Text>(find.text(label)).style?.fontWeight;
      expect(weight('Orders'), FontWeight.w700);
      expect(weight('Reports'), FontWeight.w500);
    });

    testWidgets('picking a row reports it, and sign-out is drawn as danger', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      int signedOut = 0;

      await tester.pumpWidget(
        panel(drawer(onSelect: picked.add, onSignOut: () => signedOut++)),
      );

      await tester.tap(find.text('Reports'));
      await tester.tap(find.text('Sign out'));
      expect(picked, <String>['reports']);
      expect(signedOut, 1);

      expect(
        tester.widget<Text>(find.text('Sign out')).style?.color,
        tester.element(find.text('Sign out')).colors.dangerDefault,
      );
    });

    testWidgets('opens from the start edge — the right, in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpInBothDirections(tester, shell(drawer()), (
        WidgetTester tester,
        TextDirection direction,
      ) async {
        expect(find.byType(AppNavigationDrawer), findsNothing);

        await tester.tap(find.byIcon(LucideIcons.menu));
        await _settle(tester);

        final Rect screen = tester.getRect(find.byType(AppShell));
        final Rect panel = tester.getRect(find.byType(AppNavigationDrawer));
        if (direction == TextDirection.rtl) {
          expect(panel.right, moreOrLessEquals(screen.right));
        } else {
          expect(panel.left, moreOrLessEquals(screen.left));
        }
      });
    });

    testWidgets('picking a row closes the drawer before reporting it', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];

      await tester.pumpWidget(wrapWidget(shell(drawer(onSelect: picked.add))));
      await tester.tap(find.byIcon(LucideIcons.menu));
      await _settle(tester);

      await tester.tap(find.text('Reports'));
      await _settle(tester);

      expect(picked, <String>['reports']);
      expect(find.byType(AppNavigationDrawer), findsNothing);
    });

    testWidgets('the close button closes it', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWidget(shell(drawer())));
      await tester.tap(find.byIcon(LucideIcons.menu));
      await _settle(tester);
      expect(find.byType(AppNavigationDrawer), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await _settle(tester);

      expect(find.byType(AppNavigationDrawer), findsNothing);
    });
  });

  group('AppBottomNavigation', () {
    List<AppNavDestination> destinations(int count) =>
        List<AppNavDestination>.generate(
          count,
          (int i) => AppNavDestination(
            id: '$i',
            label: 'Tab $i',
            icon: LucideIcons.circle,
          ),
        );

    test('holds two to five destinations, and says so', () {
      AppBottomNavigation bar(int count) => AppBottomNavigation(
        destinations: destinations(count),
        selectedId: '0',
        onSelect: (String id) {},
      );

      expect(() => bar(1), throwsAssertionError);
      expect(() => bar(6), throwsAssertionError);
      expect(bar(2), isA<AppBottomNavigation>());
      expect(bar(5), isA<AppBottomNavigation>());
    });

    testWidgets('the current tab reads as selected, and is heavier', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNavigation(
              destinations: _tabs,
              selectedId: 'inbox',
              onSelect: (String id) {},
            ),
          ),
        ),
      );

      expect(_selected(tester, 'Inbox, 3'), Tristate.isTrue);
      expect(_selected(tester, 'Customers'), Tristate.isFalse);
      expect(find.byType(AppBadge), findsOneWidget);

      FontWeight? weight(String label) =>
          tester.widget<Text>(find.text(label)).style?.fontWeight;
      expect(weight('Inbox'), FontWeight.w700);
      expect(weight('Orders'), FontWeight.w500);
    });

    testWidgets('tapping reports the id, and the centre action runs', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      int composed = 0;

      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomNavigation(
              destinations: _tabs,
              selectedId: 'inbox',
              onSelect: picked.add,
              centerAction: AppBottomNavAction(
                icon: LucideIcons.plus,
                label: 'New conversation',
                onPressed: () => composed++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Orders'));
      await tester.tap(find.bySemanticsLabel('New conversation'));
      expect(picked, <String>['orders']);
      expect(composed, 1);
    });

    testWidgets('stays a touch target tall, and survives large text', (
      WidgetTester tester,
    ) async {
      for (final double scale in <double>[1, 2]) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<double>(scale),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppBottomNavigation(
                  destinations: _tabs,
                  selectedId: 'inbox',
                  onSelect: (String id) {},
                ),
              ),
            ),
            textScaler: TextScaler.linear(scale),
          ),
        );

        expect(tester.takeException(), isNull, reason: 'text scale $scale');
        expect(
          tester.getSize(find.byType(AppBottomNavigation)).height,
          greaterThanOrEqualTo(56),
        );
      }
    });

    testWidgets('destinations flow from the start edge, around the centre', (
      WidgetTester tester,
    ) async {
      await pumpInBothDirections(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: AppBottomNavigation(
            destinations: _tabs,
            selectedId: 'inbox',
            onSelect: (String id) {},
            centerAction: AppBottomNavAction(
              icon: LucideIcons.plus,
              label: 'New conversation',
              onPressed: () {},
            ),
          ),
        ),
        (WidgetTester tester, TextDirection direction) async {
          double x(Finder finder) => tester.getCenter(finder).dx;
          final double first = x(find.text('Inbox'));
          final double last = x(find.text('More'));
          final double centre = x(find.byIcon(LucideIcons.plus));

          expect(
            first,
            direction == TextDirection.rtl ? greaterThan(last) : lessThan(last),
          );
          // Two on either side of the raised action, in both directions.
          final double second = x(find.text('Customers'));
          final double third = x(find.text('Orders'));
          expect(
            centre,
            allOf(
              greaterThan(second < third ? second : third),
              lessThan(second < third ? third : second),
            ),
          );
        },
      );
    });
  });

  group('AppShell', () {
    testWidgets('draws the bottom bar only with two destinations or more', (
      WidgetTester tester,
    ) async {
      Future<void> pumpWith(
        List<AppNavDestination> destinations, {
        bool selectable = true,
      }) => tester.pumpWidget(
        wrapWidget(
          AppShell(
            destinations: destinations,
            onSelect: selectable ? (String id) {} : null,
            body: _page(const AppToolbar(title: 'Inbox')),
          ),
        ),
      );

      await pumpWith(_tabs.take(1).toList());
      expect(find.byType(AppBottomNavigation), findsNothing);

      await pumpWith(_tabs.take(2).toList());
      expect(find.byType(AppBottomNavigation), findsOneWidget);

      // Tabs that cannot be picked are not navigation.
      await pumpWith(_tabs.take(2).toList(), selectable: false);
      expect(find.byType(AppBottomNavigation), findsNothing);
    });

    testWidgets('without a drawer, a toolbar inside it offers no menu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(AppShell(body: _page(const AppToolbar(title: 'Inbox')))),
      );

      expect(find.byIcon(LucideIcons.menu), findsNothing);
    });

    test('a rebuilt callback alone does not wake every toolbar below', () {
      void first() {}
      void second() {}
      const Widget child = SizedBox.shrink();

      expect(
        AppShellScope(
          hasDrawer: true,
          openDrawer: second,
          child: child,
        ).updateShouldNotify(
          AppShellScope(hasDrawer: true, openDrawer: first, child: child),
        ),
        isFalse,
      );
      expect(
        AppShellScope(
          hasDrawer: false,
          openDrawer: first,
          child: child,
        ).updateShouldNotify(
          AppShellScope(hasDrawer: true, openDrawer: first, child: child),
        ),
        isTrue,
      );
    });
  });

  group('AppScaffold', () {
    testWidgets('draws the toolbar it is given, and no bar without one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppScaffold(
            toolbar: AppToolbar(title: 'New'),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('New'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(const AppScaffold(body: SizedBox.shrink())),
      );
      expect(find.byType(AppBar), findsNothing);
    });
  });
}
