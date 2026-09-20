import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/auth/application/coordinators/session_coordinator.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/auth/domain/services/auth_service.dart';
import 'package:TajeerAi/features/auth/presentation/controllers/login_controller.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

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
  late ProviderContainer container;
  late PreferencesStorage preferences;

  setUp(() async {
    // English is stored explicitly so the assertions below read as they were
    // written. The copy now comes from AppStrings, which follows the stored
    // locale; the Arabic group at the bottom checks the other half.
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: 'en',
    });
    preferences = await PreferencesStorage.open();

    repository = FakeAuthRepository();

    coordinator = SessionCoordinator(
      authService: AuthService(repository),
      logger: Logger('test', verbose: false),
    );

    // Only the coordinator is overridden: the controller's job is to drive it
    // and map what comes back, so everything below it stays real.
    container = ProviderContainer(
      overrides: [
        sessionCoordinatorProvider.overrideWithValue(coordinator),
        preferencesStorageProvider.overrideWithValue(preferences),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    coordinator.dispose();
  });

  LoginController controller() =>
      container.read(loginControllerProvider.notifier);

  LoginState state() => container.read(loginControllerProvider);

  group('initial state', () {
    test('is idle with no errors', () {
      expect(state().isSubmitting, isFalse);
      expect(state().hasError, isFalse);
      expect(state().remember, isFalse);
    });
  });

  group('successful submission', () {
    test('returns true and leaves no error', () async {
      repository.nextSession = _session();

      final result = await controller().submit(
        identifier: 'ada@demo.test',
        password: 'secret',
      );

      expect(result, isTrue);
      expect(state().isSubmitting, isFalse);
      expect(state().hasError, isFalse);
    });

    test('passes the remember choice through', () async {
      repository.nextSession = _session();

      controller().setRemember(remember: true);
      await controller().submit(identifier: 'ada@demo.test', password: 'x');

      expect(repository.lastRemember, isTrue);
    });

    test('does not navigate -- the router reacts to auth state', () async {
      repository.nextSession = _session();

      await controller().submit(identifier: 'ada@demo.test', password: 'x');

      // Navigation belongs to the guard that watches auth state, not to a
      // form; a controller that pushed a route would fight the guard.
      expect(coordinator.state.isAuthenticated, isTrue);
    });
  });

  group('loading state', () {
    test('reports submitting while the request is in flight', () async {
      repository.nextSession = _session();

      final pending = controller().submit(
        identifier: 'ada@demo.test',
        password: 'x',
      );

      expect(state().isSubmitting, isTrue);

      await pending;

      expect(state().isSubmitting, isFalse);
    });

    test('ignores a second submission while one is running', () async {
      repository.nextSession = _session();

      final first = controller().submit(
        identifier: 'ada@demo.test',
        password: 'x',
      );
      final second = await controller().submit(
        identifier: 'ada@demo.test',
        password: 'x',
      );

      await first;

      // A double tap must not attempt two sign-ins.
      expect(second, isFalse);
      expect(repository.signInCalls, 1);
    });
  });

  group('validation errors', () {
    test('attaches messages to the fields that produced them', () async {
      final result = await controller().submit(identifier: '', password: '');

      expect(result, isFalse);
      expect(
        state().errorFor('identifier'),
        'Enter your email or phone number.',
      );
      expect(state().errorFor('password'), 'Enter your password.');
    });

    test('translates the domain keys into readable copy', () async {
      await controller().submit(identifier: 'ab', password: 'x');

      // The domain emits stable keys so the rules stay free of presentation;
      // the controller is where they become copy, in the reader's language.
      expect(
        state().errorFor('identifier'),
        'That is too short to be an email or phone number.',
      );
    });

    test('does not reach the repository for an invalid form', () async {
      await controller().submit(identifier: '', password: '');

      expect(repository.signInCalls, 0);
    });
  });

  group('authentication errors', () {
    test('shows a form-level message for rejected credentials', () async {
      repository.failureToThrow = const AuthenticationFailure(
        message: 'Not recognised.',
      );

      final result = await controller().submit(
        identifier: 'ada@demo.test',
        password: 'wrong',
      );

      expect(result, isFalse);
      expect(
        state().errorMessage,
        'Those details were not recognised. Check them and try again.',
      );
    });

    test(
      'explains being offline rather than blaming the credentials',
      () async {
        repository.failureToThrow = const TransportFailure(
          message: 'No route.',
          isOffline: true,
        );

        await controller().submit(identifier: 'ada@demo.test', password: 'x');

        expect(
          state().errorMessage,
          'No connection. Check your network and try again.',
        );
      },
    );

    test('never shows an infrastructure detail to the user', () async {
      repository.failureToThrow = const DatabaseFailure(
        message: 'SqliteException(787): FOREIGN KEY constraint failed',
      );

      await controller().submit(identifier: 'ada@demo.test', password: 'x');

      expect(state().errorMessage, 'Something went wrong. Please try again.');
      expect(state().errorMessage, isNot(contains('Sqlite')));
    });

    test('clears the submitting flag after a failure', () async {
      repository.failureToThrow = const AuthenticationFailure(message: 'Nope.');

      await controller().submit(identifier: 'ada@demo.test', password: 'x');

      expect(state().isSubmitting, isFalse);
    });
  });

  group('error clearing', () {
    test('clears errors as the user edits', () async {
      await controller().submit(identifier: '', password: '');

      expect(state().hasError, isTrue);

      controller().clearErrors();

      // A stale error under a field the user is fixing reads as the app not
      // noticing them typing.
      expect(state().hasError, isFalse);
    });

    test('clearing when there is nothing to clear is a no-op', () {
      final before = state();

      controller().clearErrors();

      expect(state(), before);
    });

    test('a new submission clears the previous error first', () async {
      repository.failureToThrow = const AuthenticationFailure(message: 'Nope.');
      await controller().submit(identifier: 'ada@demo.test', password: 'x');

      repository
        ..failureToThrow = null
        ..nextSession = _session();

      await controller().submit(identifier: 'ada@demo.test', password: 'right');

      expect(state().hasError, isFalse);
    });
  });

  group('in Arabic', () {
    late ProviderContainer arabic;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesStorage.localeKey: 'ar',
      });
      final PreferencesStorage stored = await PreferencesStorage.open();

      arabic = ProviderContainer(
        overrides: [
          sessionCoordinatorProvider.overrideWithValue(coordinator),
          preferencesStorageProvider.overrideWithValue(stored),
        ],
      );
    });

    tearDown(() => arabic.dispose());

    test('field errors read in the language the member chose', () async {
      await arabic
          .read(loginControllerProvider.notifier)
          .submit(identifier: '', password: '');

      final LoginState result = arabic.read(loginControllerProvider);
      expect(
        result.errorFor('identifier'),
        'أدخل بريدك الإلكتروني أو رقم هاتفك.',
      );
      expect(result.errorFor('password'), 'أدخل كلمة المرور.');
    });

    test('a rejected sign-in explains itself in Arabic', () async {
      repository.failureToThrow = const AuthenticationFailure(
        message: 'Not recognised.',
      );

      await arabic
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'ada@demo.test', password: 'wrong');

      expect(
        arabic.read(loginControllerProvider).errorMessage,
        'لم نتعرّف على هذه البيانات. تحقّق منها وحاول مرة أخرى.',
      );
    });

    test('an infrastructure detail stays hidden in either language', () async {
      repository.failureToThrow = const DatabaseFailure(
        message: 'SqliteException(787): FOREIGN KEY constraint failed',
      );

      await arabic
          .read(loginControllerProvider.notifier)
          .submit(identifier: 'ada@demo.test', password: 'x');

      final String? message = arabic.read(loginControllerProvider).errorMessage;
      expect(message, 'حدث خطأ ما. يرجى المحاولة مرة أخرى.');
      expect(message, isNot(contains('Sqlite')));
    });
  });
}
