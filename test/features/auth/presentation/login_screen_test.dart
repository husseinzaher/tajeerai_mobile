import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/design_system/auth/social_button.dart';
import 'package:tajeerai_mobile/design_system/auth/social_provider_mark.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/feedback/inline_error.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_checkbox.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_text_field.dart';
import 'package:tajeerai_mobile/design_system/inputs/password_field.dart';
import 'package:tajeerai_mobile/design_system/loaders/spinner.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/presentation/controllers/login_controller.dart';
import 'package:tajeerai_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:tajeerai_mobile/infrastructure/device/platform_info.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/storage/preferences_storage.dart';

import '../../../support/widget_harness.dart';
import '../domain/fakes/fake_auth_repository.dart';

const PlatformInfo _platformInfo = PlatformInfo(
  appVersion: '1.0.0',
  buildNumber: '1',
  operatingSystem: 'android',
);

Session _session() => const Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
  ),
);

/// Taps [finder] the way a person does on a short screen: scroll to it first.
///
/// The sign-in form scrolls by design — `AppAuthLayout` centres it when there is
/// room and scrolls when there is not — and on the test surface's 800x600 the
/// logo pushes the submit button below the fold. A bare `tap` there lands
/// outside the screen and submits nothing, which fails the test for a reason
/// that has nothing to do with what the test is about.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  late FakeAuthRepository repository;
  late SessionCoordinator coordinator;
  late PreferencesStorage preferences;

  setUp(() async {
    // English is stored explicitly: these assertions predate the Arabic copy
    // and read in English. A fresh install reads Arabic, and has its own test.
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: 'en',
    });
    preferences = await PreferencesStorage.open();

    repository = FakeAuthRepository();

    coordinator = SessionCoordinator(
      authService: AuthService(repository),
      logger: Logger('test', verbose: false),
    );
  });

  tearDown(() => coordinator.dispose());

  /// The screen wired to a real controller over a fake repository, so the test
  /// exercises the whole presentation path rather than a stubbed controller.
  Widget subject({Brightness brightness = Brightness.light}) {
    return ProviderScope(
      overrides: [
        sessionCoordinatorProvider.overrideWithValue(coordinator),
        preferencesStorageProvider.overrideWithValue(preferences),
        platformInfoProvider.overrideWithValue(_platformInfo),
      ],
      child: wrapWidget(const LoginScreen(), brightness: brightness),
    );
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String identifier = 'ada@demo.test',
    String password = 'secret',
  }) async {
    await tester.enterText(find.byType(AppTextField).first, identifier);
    await tester.enterText(find.byType(AppTextField).last, password);
    await tapVisible(tester, find.text('Sign in').last);
    await tester.pump();
  }

  /// The screen with a deployment that offers providers.
  Widget withProviders(List<String> providers) {
    return ProviderScope(
      overrides: [
        sessionCoordinatorProvider.overrideWithValue(coordinator),
        preferencesStorageProvider.overrideWithValue(preferences),
        platformInfoProvider.overrideWithValue(_platformInfo),
        socialProvidersProvider.overrideWith((Ref ref) async => providers),
      ],
      child: wrapWidget(const LoginScreen()),
    );
  }

  group('signing in with a provider', () {
    /*
      A fresh deployment has no client secret filled in and offers none, which
      is why the list is asked for. A button that leads to a 404 is worse than
      no button - and an empty section would still cost a gap under the sign-in
      button.
    */
    testWidgets('draws nothing at all when the server names no providers', (
      tester,
    ) async {
      await tester.pumpWidget(withProviders(const <String>[]));
      await tester.pumpAndSettle();

      expect(find.byType(AppSocialButton), findsNothing);
      expect(find.text('Or continue with'), findsNothing);
    });

    testWidgets('draws one button per provider the server named', (
      tester,
    ) async {
      await tester.pumpWidget(
        withProviders(const <String>['google', 'facebook']),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppSocialButton), findsNWidgets(2));
      expect(find.text('Or continue with'), findsOneWidget);
      expect(find.byType(AppSocialProviderMark), findsNWidgets(2));
    });

    /* The server's vocabulary grows; an unknown provider is drawn, not dropped. */
    testWidgets('draws a provider this build has never heard of', (
      tester,
    ) async {
      await tester.pumpWidget(withProviders(const <String>['apple']));
      await tester.pumpAndSettle();

      expect(find.byType(AppSocialButton), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // unknown providers keep an initial
    });
  });

  group('initial render', () {
    testWidgets('shows the form built from the design system', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Email or phone'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Built from design-system parts, not bespoke widgets. Two buttons: the
      // submit, and the language switcher in the corner.
      expect(find.byType(AppTextField), findsNWidgets(2));
      expect(find.byType(AppButton), findsNWidgets(2));
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(subject(brightness: Brightness.dark));

      expect(find.byType(AppTextField), findsNWidgets(2));
    });

    testWidgets('shows no error before anything is submitted', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.byType(AppInlineError), findsNothing);
    });

    testWidgets('shows the app version in the footer', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('shows field errors for an empty form', (tester) async {
      await tester.pumpWidget(subject());

      await tapVisible(tester, find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Enter your email or phone number.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repository.signInCalls, 0);
    });

    testWidgets('clears an error once the user edits the field', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      await tapVisible(tester, find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Enter your password.'), findsOneWidget);

      await tester.enterText(find.byType(AppTextField).first, 'a@b.test');
      await tester.pump();

      expect(find.text('Enter your password.'), findsNothing);
    });
  });

  group('loading state', () {
    testWidgets('shows a spinner in the button while submitting', (
      tester,
    ) async {
      repository
        ..nextSession = _session()
        // Hold the request open so the in-flight state is observable.
        ..signInGate = Completer<void>();

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester);

      expect(find.byType(AppSpinner), findsOneWidget);

      repository.signInGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('disables the fields while submitting', (tester) async {
      repository
        ..nextSession = _session()
        ..signInGate = Completer<void>();

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester);

      final field = tester.widget<AppTextField>(
        find.byType(AppTextField).first,
      );

      expect(field.enabled, isFalse);

      repository.signInGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('error state', () {
    testWidgets('shows a form-level message for rejected credentials', (
      tester,
    ) async {
      repository.failureToThrow = const AuthenticationFailure(
        message: 'Not recognised.',
      );

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester, password: 'wrong');
      await tester.pumpAndSettle();

      expect(find.byType(AppInlineError), findsOneWidget);
      expect(
        find.text(
          'Those details were not recognised. Check them and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('explains being offline', (tester) async {
      repository.failureToThrow = const TransportFailure(
        message: 'No route.',
        isOffline: true,
      );

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('leaves the form usable after a failure', (tester) async {
      repository.failureToThrow = const AuthenticationFailure(message: 'Nope.');

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      final field = tester.widget<AppTextField>(
        find.byType(AppTextField).first,
      );

      expect(field.enabled, isTrue);
    });
  });

  group('success', () {
    testWidgets('establishes the session', (tester) async {
      repository.nextSession = _session();

      await tester.pumpWidget(subject());
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(coordinator.state.isAuthenticated, isTrue);
      expect(find.byType(AppInlineError), findsNothing);
    });
  });

  group('password visibility', () {
    testWidgets('toggles between hidden and shown', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.bySemanticsLabel('Show password'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Show password'));
      await tester.pump();

      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    });
  });

  group('remember me', () {
    testWidgets('is off by default and can be turned on', (tester) async {
      repository.nextSession = _session();

      await tester.pumpWidget(subject());

      await tapVisible(tester, find.text('Keep me signed in'));
      await tester.pump();

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      // It changes the refresh token's lifetime server-side.
      expect(repository.lastRemember, isTrue);
    });
  });

  group('the reference design', () {
    testWidgets('greets, and is built from the auth family', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(AppPasswordField), findsOneWidget);
      expect(find.byType(AppCheckbox), findsOneWidget);
    });

    testWidgets('offers no social sign-in until a deployment configures one', (
      tester,
    ) async {
      // The flow exists now; the buttons still wait to be told which providers
      // are real. A button that leads to a 404 because nobody filled in a
      // client secret is worse than an absent one.
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.byType(AppSocialButton), findsNothing);
    });
  });

  group('language', () {
    testWidgets('a fresh install reads Arabic', (tester) async {
      late PreferencesStorage fresh;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        fresh = await PreferencesStorage.open();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionCoordinatorProvider.overrideWithValue(coordinator),
            preferencesStorageProvider.overrideWithValue(fresh),
            platformInfoProvider.overrideWithValue(_platformInfo),
          ],
          child: wrapWidget(
            const LoginScreen(),
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
          ),
        ),
      );

      expect(find.text('مرحباً بعودتك'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
    });

    testWidgets('email and password stay left-to-right in Arabic', (
      tester,
    ) async {
      late PreferencesStorage fresh;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        fresh = await PreferencesStorage.open();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionCoordinatorProvider.overrideWithValue(coordinator),
            preferencesStorageProvider.overrideWithValue(fresh),
            platformInfoProvider.overrideWithValue(_platformInfo),
          ],
          child: wrapWidget(
            const LoginScreen(),
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
          ),
        ),
      );

      final List<AppTextField> fields = tester
          .widgetList<AppTextField>(find.byType(AppTextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields.every((AppTextField field) => field.textDirection == TextDirection.ltr), isTrue);
    });

    testWidgets('the switcher changes the copy without leaving the screen', (
      tester,
    ) async {
      await tester.pumpWidget(subject());
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Language: English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('مرحباً بعودتك'), findsOneWidget);
      expect(preferences.readString(PreferencesStorage.localeKey), 'ar');
    });
  });
}
