import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/app/router/routes.dart';
import 'package:tajeerai_mobile/app/shell/authenticated_shell.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/display/list_item.dart';
import 'package:tajeerai_mobile/design_system/layouts/app_scaffold.dart';
import 'package:tajeerai_mobile/design_system/shell/bottom_navigation.dart';
import 'package:tajeerai_mobile/design_system/shell/toolbar.dart';
import 'package:tajeerai_mobile/features/auth/application/state/auth_state.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tajeerai_mobile/infrastructure/storage/preferences_storage.dart';

const AuthenticatedUser _ada = AuthenticatedUser(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@demo.test',
  role: 'owner',
  locale: 'en',
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

  /// The shell under a real router, so picking a destination really moves.
  Widget subject({Session? session = _inStore}) {
    final GoRouter router = GoRouter(
      initialLocation: '/elsewhere',
      routes: <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) =>
              AuthenticatedShell(child: child),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.conversations,
              builder: (BuildContext context, GoRouterState state) =>
                  _screen('Inbox screen'),
            ),
            GoRoute(
              path: '/elsewhere',
              builder: (BuildContext context, GoRouterState state) =>
                  _screen('Elsewhere'),
            ),
          ],
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

      expect(find.text('Elsewhere'), findsOneWidget);
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

    testWidgets('before the session resolves, there is no profile to show', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject(session: null));
      await _openDrawer(tester);

      expect(find.byType(AppListItem), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('only the Inbox exists, so there is no bottom bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());

      expect(find.byType(AppBottomNavigation), findsNothing);
    });

    testWidgets('picking the Inbox goes to the Inbox', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      await tester.tap(find.text('Inbox'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Inbox screen'), findsOneWidget);
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
      expect(find.text('Elsewhere'), findsOneWidget);
    });
  });

  group('in Arabic', () {
    setUp(() => storeLocale('ar'));

    testWidgets('the drawer speaks the member\'s language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await _openDrawer(tester);

      expect(find.text('صندوق الوارد'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  });
}
