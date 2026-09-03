import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/presentation/controllers/login_controller.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

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

  setUp(() {
    repository = FakeAuthRepository();

    coordinator = SessionCoordinator(
      authService: AuthService(repository),
      logger: Logger('test', verbose: false),
    );

    // Only the coordinator is overridden: the controller's job is to drive it
    // and map what comes back, so everything below it stays real.
    container = ProviderContainer(
      overrides: [sessionCoordinatorProvider.overrideWithValue(coordinator)],
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
      // the controller is where they become English.
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
}
