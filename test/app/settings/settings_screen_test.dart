import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/settings/settings_screen.dart';
import 'package:TajeerAi/app/theme/theme_mode_manager.dart';
import 'package:TajeerAi/design_system/design_system.dart';
import 'package:TajeerAi/features/auth/application/state/auth_state.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/auth/presentation/controllers/auth_controller.dart';
import 'package:TajeerAi/infrastructure/device/platform_info.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

import '../../support/widget_harness.dart';

const AuthenticatedUser _ada = AuthenticatedUser(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@demo.test',
  phone: '+966551234567',
  role: 'owner',
  locale: 'en',
  permissions: <String>{'manage:all'},
);

const Session _owner = Session(
  user: _ada,
  workspace: Workspace(
    id: 'w1',
    name: 'Elite Store',
    slug: 'elite',
    locale: 'en',
  ),
);

/// The session, held still, with a sign-out that only counts.
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

void main() {
  late PreferencesStorage preferences;
  late _Session controller;

  Future<void> storeLocale(String code) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: code,
    });
    preferences = await PreferencesStorage.open();
  }

  /// The screen, tall enough that every section is built at once.
  Future<void> pump(
    WidgetTester tester, {
    Session? session = _owner,
    Locale locale = const Locale('en'),
    TextScaler textScaler = TextScaler.noScaling,
    Size size = const Size(390, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStorageProvider.overrideWithValue(preferences),
          platformInfoProvider.overrideWithValue(
            const PlatformInfo(
              appVersion: '1.4.0',
              buildNumber: '27',
              operatingSystem: 'android',
            ),
          ),
          authControllerProvider.overrideWith(
            () => controller = _Session(session),
          ),
        ],
        child: wrapWidget(
          const SettingsScreen(),
          locale: locale,
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          textScaler: textScaler,
          size: size,
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('in English', () {
    setUp(() => storeLocale('en'));

    testWidgets('names who is signed in, to which store, as what', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('ada@demo.test'), findsOneWidget);
      expect(find.text('+966551234567'), findsOneWidget);
      // Once under the name, once as the store row.
      expect(find.text('Elite Store'), findsNWidgets(2));
    });

    testWidgets('leaves out a phone the account does not have', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        session: const Session(
          user: AuthenticatedUser(
            id: 'u1',
            name: 'Ada Lovelace',
            email: 'ada@demo.test',
            role: 'agent',
            locale: 'en',
          ),
        ),
      );

      expect(find.text('Phone'), findsNothing);
      expect(find.text('Agent'), findsOneWidget);
    });

    testWidgets('shows a role this build does not know as it was sent', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        session: const Session(
          user: AuthenticatedUser(
            id: 'u1',
            name: 'Ada Lovelace',
            email: 'ada@demo.test',
            role: 'auditor',
            locale: 'en',
          ),
        ),
      );

      expect(find.text('auditor'), findsOneWidget);
    });

    testWidgets('picking an appearance keeps it', (WidgetTester tester) async {
      await pump(tester);

      await tester.tap(find.text('Dark'));
      await settle(tester);

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(container.read(themeSelectionProvider).mode, AppThemeMode.dark);
      expect(preferences.readString(PreferencesStorage.themeModeKey), 'dark');
    });

    testWidgets('picking a language redraws the screen in it', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('العربية'));
      await settle(tester);

      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('says which build this is', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text('1.4.0 (27)'), findsOneWidget);
    });

    testWidgets('signing out asks first, and cancelling keeps the session', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await settle(tester);
      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      expect(controller.signOuts, 0);
    });

    testWidgets('confirming signs out', (WidgetTester tester) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Sign out'),
        ),
      );
      await settle(tester);

      expect(controller.signOuts, 1);
    });

    testWidgets('before the session resolves, the header holds its place', (
      WidgetTester tester,
    ) async {
      await pump(tester, session: null);

      expect(find.byType(AppSkeleton), findsWidgets);
      expect(find.text('Account'), findsNothing);
    });

    testWidgets('twice the text size on a narrow phone still fits', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        textScaler: const TextScaler.linear(2),
        size: const Size(320, 3200),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('in Arabic', () {
    setUp(() => storeLocale('ar'));

    testWidgets('speaks the member\'s language', (WidgetTester tester) async {
      await pump(tester, locale: const Locale('ar'));

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('المالك'), findsOneWidget);
      expect(find.text('المظهر'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'تسجيل الخروج'), findsOneWidget);
    });
  });
}
