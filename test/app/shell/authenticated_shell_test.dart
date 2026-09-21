import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/router/routes.dart';
import 'package:TajeerAi/app/shell/authenticated_shell.dart';
import 'package:TajeerAi/app/shell/shell_destination.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/display/profile_header.dart';
import 'package:TajeerAi/design_system/layouts/app_scaffold.dart';
import 'package:TajeerAi/design_system/shell/bottom_navigation.dart';
import 'package:TajeerAi/design_system/shell/navigation_drawer.dart';
import 'package:TajeerAi/design_system/shell/toolbar.dart';
import 'package:TajeerAi/features/auth/application/state/auth_state.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/auth/presentation/controllers/auth_controller.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

const AuthenticatedUser _ada = AuthenticatedUser(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@demo.test',
  role: 'owner',
  locale: 'en',
  // What an owner holds.
  permissions: <String>{'manage:all'},
);

const Session _inStore = Session(
  user: _ada,
  workspace: Workspace(
    id: 'w1',
    name: 'Elite Store',
    slug: 'elite',
    locale: 'en',
  ),
);

/// The session, held still: no coordinator, no repository, and a sign-out
/// that only counts.
class _Session extends AuthController {
  _Session(this.session);

  final Session? session;
  int signOuts = 0;

  @override
  AuthState build() => session == null
      ? const AuthState.unknown()
      : AuthState.authenticated(session!);

  @override
  Future<void> signOut() async => signOuts++;
}

/// A signed-in screen, drawing its own toolbar the way the Inbox does.
Widget _screen(String body) => AppScaffold(
  toolbar: const AppToolbar(title: 'Screen'),
  body: Center(child: Text(body)),
);

/// [text] inside the open drawer, not the same word on the bottom bar.
Finder _inDrawer(String text) => find.descendant(
  of: find.byType(AppNavigationDrawer),
  matching: find.text(text),
);

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.menu));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late PreferencesStorage preferences;
  late _Session controller;

  Future<void> storeLocale(String code) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: code,
    });
    preferences = await PreferencesStorage.open();
  }

  /// The shell under a real router shaped like the app's -- one branch per
  /// destination, each with a screen one step in -- so picking a destination
  /// really moves. It opens one step into the Inbox.
  Widget subject({Session? session = _inStore}) {
    final GoRouter router = GoRouter(
      initialLocation: '${ShellDestination.inbox.path}/deeper',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) => AuthenticatedShell(navigationShell: navigationShell),
          branches: <StatefulShellBranch>[
            for (final ShellDestination destination in ShellDestination.values)
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: destination.path,
                    builder: (BuildContext context, GoRouterState state) =>
                        _screen('${destination.name} start'),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'deeper',
                        builder: (BuildContext context, GoRouterState state) =>
                            _screen('${destination.name} deeper'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        // The blog lives outside the shell, which is the whole reason it is a
        // footer action rather than a tab. The test router has to carry it too
        // or the drawer's link has nowhere to go.
        GoRoute(
          path: AppRoutes.blog,
          builder: (BuildContext context, GoRouterState state) =>
              _screen('blog'),
        ),
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(preferences),
        authControllerProvider.overrideWith(
          () => controller = _Session(session),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(TajeerPreset.fallback, Brightness.light),
        routerConfig: router,
      ),
    );
  }

  group('in English', () {
    setUp(() => storeLocale('en'));

    testWidgets('a signed-in screen gets the menu button without asking', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());

      expect(find.text('inbox deeper'), findsOneWidget);
      expect(find.byIcon(LucideIcons.menu), findsOneWidget);
    });

    testWidgets('the drawer names the member and the store', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Elite Store'), findsOneWidget);
    });

    testWidgets('without a workspace, it names the account instead', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject(session: const Session(user: _ada)));
      await _openDrawer(tester);

      expect(find.text('ada@demo.test'), findsOneWidget);
    });

    testWidgets('before the session resolves, there is nothing to offer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject(session: null));
      await _openDrawer(tester);

      expect(find.byType(AppProfileHeader), findsNothing);
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('two destinations on offer, so the bottom bar appears', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());

      expect(find.byType(AppBottomNavigation), findsOneWidget);
    });

    testWidgets('the bottom bar moves between destinations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());

      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNavigation),
          matching: find.text('Settings'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('settings start'), findsOneWidget);
    });

    testWidgets(
      'picking the destination already open returns it to its start',
      (WidgetTester tester) async {
        await tester.pumpWidget(subject());
        await _openDrawer(tester);

        await tester.tap(_inDrawer('Inbox'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('inbox start'), findsOneWidget);
      },
    );

    testWidgets('the account at the top of the drawer opens Settings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      await tester.tap(find.text('Ada Lovelace'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('settings start'), findsOneWidget);
    });

    testWidgets('a member without the permission is offered Settings alone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        subject(
          session: const Session(
            user: AuthenticatedUser(
              id: 'u2',
              name: 'Grace Hopper',
              email: 'grace@demo.test',
              role: 'member',
              locale: 'en',
              // A permission no destination is gated on, which is the point:
              // this member is offered Settings because nothing else is open
              // to them, not because they hold nothing at all.
              permissions: <String>{'read:Invoice'},
            ),
          ),
        ),
      );

      // One destination is a label, not a tab bar.
      expect(find.byType(AppBottomNavigation), findsNothing);

      await _openDrawer(tester);

      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Inbox'), findsNothing);
      expect(_inDrawer('Settings'), findsOneWidget);
    });

    testWidgets('the drawer opens the blog, which is not one of the tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      await tester.tap(_inDrawer('Blog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('blog'), findsOneWidget);
      // Pushed, not switched to: the member's tab is still underneath, so
      // closing the article returns them to where they were reading.
      expect(find.byType(AppBottomNavigation), findsNothing);
    });

    testWidgets('signing out ends the session and navigates nowhere itself', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The router's redirect moves a signed-out member to sign-in. The shell
      // only asks.
      expect(controller.signOuts, 1);
      expect(find.text('inbox deeper'), findsOneWidget);
    });
  });

  group('in Arabic', () {
    setUp(() => storeLocale('ar'));

    testWidgets('the drawer speaks the member\'s language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      expect(_inDrawer('المدونة'), findsOneWidget);
      expect(_inDrawer('صندوق الوارد'), findsOneWidget);
      expect(_inDrawer('الإعدادات'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });
}
