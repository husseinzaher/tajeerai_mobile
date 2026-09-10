import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/feedback/inline_error.dart';
import 'package:tajeerai_mobile/design_system/inputs/app_text_field.dart';
import 'package:tajeerai_mobile/design_system/loaders/spinner.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

import '../../../support/widget_harness.dart';
import '../domain/fakes/fake_auth_repository.dart';

Session _session() => const Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
  ),
);

void main() {
  late FakeAuthRepository repository;
  late SessionCoordinator coordinator;

  setUp(() {
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
      overrides: [sessionCoordinatorProvider.overrideWithValue(coordinator)],
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
    await tester.tap(find.text('Sign in').last);
    await tester.pump();
  }

  group('initial render', () {
    testWidgets('shows the form built from the design system', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Email or phone'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Built from design-system parts, not bespoke widgets.
      expect(find.byType(AppTextField), findsNWidgets(2));
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(subject(brightness: Brightness.dark));

      expect(find.byType(AppTextField), findsNWidgets(2));
    });

    testWidgets('shows no error before anything is submitted', (tester) async {
      await tester.pumpWidget(subject());

      expect(find.byType(AppInlineError), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('shows field errors for an empty form', (tester) async {
      await tester.pumpWidget(subject());

      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Enter your email or phone number.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repository.signInCalls, 0);
    });

    testWidgets('clears an error once the user edits the field', (
      tester,
    ) async {
      await tester.pumpWidget(subject());

      await tester.tap(find.text('Sign in').last);
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

      await tester.tap(find.text('Keep me signed in'));
      await tester.pump();

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      // It changes the refresh token's lifetime server-side.
      expect(repository.lastRemember, isTrue);
    });
  });
}
