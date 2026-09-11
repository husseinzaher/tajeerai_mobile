import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../buttons/app_button.dart';
import '../../display/badge.dart';
import '../../display/status_dot.dart';
import '../../feedback/empty_state.dart';
import '../../layouts/app_scaffold.dart';
import '../../shell/app_shell.dart';
import '../../shell/bottom_navigation.dart';
import '../../shell/navigation_destination.dart';
import '../../shell/navigation_drawer.dart';
import '../../shell/shell_scope.dart';
import '../../shell/toolbar.dart';
import '../showcase_fixtures.dart';
import '../showcase_section.dart';

const List<AppNavDestination> _tabs = <AppNavDestination>[
  AppNavDestination(
    id: 'inbox',
    label: 'المحادثات',
    icon: LucideIcons.messagesSquare,
    badgeCount: 3,
  ),
  AppNavDestination(id: 'customers', label: 'العملاء', icon: LucideIcons.users),
  AppNavDestination(
    id: 'notifications',
    label: 'الإشعارات',
    icon: LucideIcons.bell,
    badgeCount: 12,
  ),
  AppNavDestination(id: 'more', label: 'المزيد', icon: LucideIcons.ellipsis),
];

const AppDrawerProfile _profile = AppDrawerProfile(
  name: 'أحمد محمد',
  subtitle: ShowcaseFixtures.store,
);

const AppBottomNavAction _compose = AppBottomNavAction(
  icon: LucideIcons.plus,
  label: 'محادثة جديدة',
  onPressed: _noop,
);

void _noop() {}

/// A toolbar is a `PreferredSize`, so on its own in a page it needs its height.
Widget _bar(Widget toolbar) =>
    SizedBox(height: AppToolbar.height, child: toolbar);

ShowcaseSection shellSection() => ShowcaseSection(
  title: 'App shell',
  icon: LucideIcons.menu,
  description:
      'The frame around the signed-in app. The shell owns the drawer and the '
      'bottom bar; each screen owns its toolbar, because that is the part that '
      'differs from screen to screen.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Toolbar',
      description:
          'One widget in three modes — normal, search, selection — so the '
          'height and the way back never drift between them. The menu button '
          'is not placed by hand: it appears because the toolbar sits inside a '
          'shell with a drawer. The back chevron points toward the start of the '
          'line, so it mirrors in Arabic.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          _bar(
            AppShellScope(
              hasDrawer: true,
              openDrawer: _noop,
              child: AppToolbar(
                title: 'المحادثات',
                centerTitle: true,
                actions: <Widget>[
                  AppButton.icon(
                    icon: const Icon(LucideIcons.search),
                    semanticLabel: 'بحث',
                    onPressed: _noop,
                  ),
                  AppButton.icon(
                    icon: const Icon(LucideIcons.bell),
                    semanticLabel: 'الإشعارات',
                    badge: const AppBadge.dot(),
                    onPressed: _noop,
                  ),
                ],
              ),
            ),
          ),
          _bar(
            const AppToolbar(
              title: 'تفاصيل الطلب',
              subtitle: '#1042',
              showBack: true,
              onBack: _noop,
            ),
          ),
          const _ToolbarSearchDemo(),
          _bar(
            AppToolbar(
              mode: AppToolbarMode.selection,
              selectionCount: 3,
              onSelectionClose: _noop,
              selectionActions: <Widget>[
                AppButton.icon(
                  icon: const Icon(LucideIcons.archive),
                  semanticLabel: 'أرشفة',
                  onPressed: _noop,
                ),
                AppButton.icon(
                  icon: const Icon(LucideIcons.trash2),
                  semanticLabel: 'حذف',
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Conversation header',
      description:
          'A preset of the same toolbar, not a fourth one: the person, their '
          'presence and the way back.',
      builder: (BuildContext context) => _bar(
        AppToolbar.conversation(
          title: ShowcaseFixtures.customer,
          subtitle: 'متصلة الآن',
          presence: AppPresence.online,
          onBack: _noop,
          actions: <Widget>[
            AppButton.icon(
              icon: const Icon(LucideIcons.phone),
              semanticLabel: 'اتصال',
              onPressed: _noop,
            ),
            AppButton.icon(
              icon: const Icon(LucideIcons.ellipsisVertical),
              semanticLabel: 'المزيد',
              onPressed: _noop,
            ),
          ],
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Navigation drawer',
      description:
          'The current destination is marked by a tint, a heavier label and the '
          'selected semantics flag together — never by colour alone. In the app '
          'it opens from the start edge, the right in Arabic.',
      builder: (BuildContext context) => const SizedBox(
        height: 700,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: _DrawerDemo(),
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Bottom navigation',
      description:
          'Two to five destinations, enforced. The first sits at the start edge, '
          'so in Arabic it is on the right.',
      builder: (BuildContext context) => const _BottomNavDemo(),
    ),
    ShowcaseExample(
      name: 'The shell',
      description:
          'A screen inside the shell. The menu button in its toolbar opens the '
          'shell\'s drawer, and nothing in the screen wired that up.',
      builder: (BuildContext context) =>
          const SizedBox(height: 560, child: _ShellDemo()),
    ),
  ],
);

class _ToolbarSearchDemo extends StatefulWidget {
  const _ToolbarSearchDemo();

  @override
  State<_ToolbarSearchDemo> createState() => _ToolbarSearchDemoState();
}

class _ToolbarSearchDemoState extends State<_ToolbarSearchDemo> {
  final TextEditingController _query = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _bar(
    AppToolbar(
      mode: _searching ? AppToolbarMode.search : AppToolbarMode.normal,
      title: 'العملاء',
      searchController: _query,
      searchHint: 'ابحث عن عميل',
      onSearchClose: () => setState(() {
        _searching = false;
        _query.clear();
      }),
      actions: <Widget>[
        AppButton.icon(
          icon: const Icon(LucideIcons.search),
          semanticLabel: 'بحث',
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    ),
  );
}

class _DrawerDemo extends StatefulWidget {
  const _DrawerDemo();

  @override
  State<_DrawerDemo> createState() => _DrawerDemoState();
}

class _DrawerDemoState extends State<_DrawerDemo> {
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) => AppNavigationDrawer(
    profile: _profile,
    selectedId: _selected,
    onSelect: (String id) => setState(() => _selected = id),
    groups: const <AppNavGroup>[
      AppNavGroup(
        destinations: <AppNavDestination>[
          AppNavDestination(
            id: 'inbox',
            label: 'المحادثات',
            icon: LucideIcons.messagesSquare,
            badgeCount: 3,
          ),
          AppNavDestination(
            id: 'customers',
            label: 'العملاء',
            icon: LucideIcons.users,
          ),
          AppNavDestination(
            id: 'orders',
            label: 'الطلبات',
            icon: LucideIcons.shoppingBag,
            badgeCount: 12,
          ),
          AppNavDestination(
            id: 'products',
            label: 'المنتجات',
            icon: LucideIcons.package,
          ),
        ],
      ),
      AppNavGroup(
        label: 'النمو',
        destinations: <AppNavDestination>[
          AppNavDestination(
            id: 'reports',
            label: 'التقارير',
            icon: LucideIcons.chartColumn,
          ),
          AppNavDestination(
            id: 'marketing',
            label: 'التسويق',
            icon: LucideIcons.megaphone,
          ),
        ],
      ),
    ],
    footerActions: const <AppDrawerAction>[
      AppDrawerAction(
        label: 'الإعدادات',
        icon: LucideIcons.settings,
        onPressed: _noop,
      ),
      AppDrawerAction(
        label: 'مركز المساعدة',
        icon: LucideIcons.circleHelp,
        onPressed: _noop,
      ),
      AppDrawerAction(
        label: 'تسجيل الخروج',
        icon: LucideIcons.logOut,
        destructive: true,
        onPressed: _noop,
      ),
    ],
  );
}

class _BottomNavDemo extends StatefulWidget {
  const _BottomNavDemo();

  @override
  State<_BottomNavDemo> createState() => _BottomNavDemoState();
}

class _BottomNavDemoState extends State<_BottomNavDemo> {
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    destinations: _tabs,
    selectedId: _selected,
    onSelect: (String id) => setState(() => _selected = id),
    centerAction: _compose,
  );
}

class _ShellDemo extends StatefulWidget {
  const _ShellDemo();

  @override
  State<_ShellDemo> createState() => _ShellDemoState();
}

class _ShellDemoState extends State<_ShellDemo> {
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) {
    final String title = _tabs
        .firstWhere((AppNavDestination d) => d.id == _selected)
        .label;

    return AppShell(
      drawer: AppNavigationDrawer(
        profile: _profile,
        selectedId: _selected,
        onSelect: (String id) => setState(() => _selected = id),
        groups: const <AppNavGroup>[AppNavGroup(destinations: _tabs)],
      ),
      destinations: _tabs,
      selectedId: _selected,
      onSelect: (String id) => setState(() => _selected = id),
      centerAction: _compose,
      body: AppScaffold(
        toolbar: AppToolbar(title: title, centerTitle: true),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(TajeerSpacing.md),
          child: AppEmptyState(
            title: 'افتح القائمة من أعلى الشاشة',
            description:
                'زر القائمة ظهر لأن الشاشة داخل غلاف فيه قائمة جانبية.',
            icon: LucideIcons.menu,
            bordered: false,
          ),
        ),
      ),
    );
  }
}
