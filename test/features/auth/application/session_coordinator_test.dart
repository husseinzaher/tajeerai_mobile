import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/application/events/auth_events.dart';
import 'package:tajeerai_mobile/features/auth/application/state/auth_state.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
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
  workspace: Workspace(id: 't1', name: 'Demo', slug: 'demo', locale: 'ar'),
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

  group('initial state', () {
    test('starts unknown, not unauthenticated', () {
      // Routing on "not authenticated" during start-up flashes the login
      // screen at an already-signed-in user on every cold start.
      expect(coordinator.state.status, AuthStatus.unknown);
      expect(coordinator.state.isResolved, isFalse);
    });
  });

  group('restore', () {
    test('publishes an authenticated state from the cache', () async {
      repository.cached = _session();

      await coordinator.restore();

      expect(coordinator.state.isAuthenticated, isTrue);
      expect(coordinator.currentUserId, 'u1');
      expect(coordinator.currentWorkspaceId, 't1');
    });

    test('announces a restored sign-in distinctly', () async {
      final events = <AuthEvent>[];
      final subscription = coordinator.events.listen(events.add);

      repository.cached = _session();
      await coordinator.restore();
      await pumpEventQueue();
      await subscription.cancel();

      final signedIn = events.whereType<SignedIn>().single;

      // A restored session already holds data and needs an incremental
      // catch-up, not a full first sync.
      expect(signedIn.wasRestored, isTrue);
    });

    test('resolves to unauthenticated when there is no session', () async {
      await coordinator.restore();

      expect(coordinator.state.status, AuthStatus.unauthenticated);
      expect(coordinator.state.isResolved, isTrue);
    });

    test('always resolves, even when restoring throws', () async {
      repository.failureToThrow = StateError('corrupted cache');

      await coordinator.restore();

      // Leaving the status unknown would hang the app on its splash screen
      // forever, which is worse than showing the login form.
      expect(coordinator.state.isResolved, isTrue);
      expect(coordinator.state.status, AuthStatus.unauthenticated);
    });
  });

  group('signIn', () {
    test('publishes the session and announces a fresh sign-in', () async {
      final events = <AuthEvent>[];
      final subscription = coordinator.events.listen(events.add);

      repository.nextSession = _session();

      await coordinator.signIn(identifier: 'ada@demo.test', password: 'secret');

      await pumpEventQueue();
      await subscription.cancel();

      expect(coordinator.state.isAuthenticated, isTrue);
      expect(events.whereType<SignedIn>().single.wasRestored, isFalse);
    });

    test('rethrows the failure and leaves the state unauthenticated', () async {
      repository.failureToThrow = const AuthenticationFailure(
        message: 'Not recognised.',
      );

      await expectLater(
        coordinator.signIn(identifier: 'ada@demo.test', password: 'wrong'),
        throwsA(isA<AuthenticationFailure>()),
      );

      expect(coordinator.state.isAuthenticated, isFalse);
      expect(coordinator.state.failure, isA<AuthenticationFailure>());
    });

    test('wraps an unexpected error as a failure', () async {
      repository.failureToThrow = StateError('boom');

      await expectLater(
        coordinator.signIn(identifier: 'ada@demo.test', password: 'x'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('signOut', () {
    test('clears the session and announces it', () async {
      final events = <AuthEvent>[];
      final subscription = coordinator.events.listen(events.add);

      repository.cached = _session();
      await coordinator.restore();

      await coordinator.signOut();
      await pumpEventQueue();
      await subscription.cancel();

      expect(coordinator.state.isAuthenticated, isFalse);
      expect(coordinator.currentUserId, isNull);
      expect(events.whereType<SignedOut>().last.wasExpired, isFalse);
    });

    test('marks an expired sign-out so the login screen can explain', () async {
      final events = <AuthEvent>[];
      final subscription = coordinator.events.listen(events.add);

      await coordinator.signOut(expired: true);
      await pumpEventQueue();
      await subscription.cancel();

      expect(events.whereType<SignedOut>().single.wasExpired, isTrue);
      expect(
        coordinator.state.failure,
        isA<AuthenticationFailure>().having(
          (failure) => failure.sessionExpired,
          'sessionExpired',
          isTrue,
        ),
      );
    });

    test('still clears local state when the server call fails', () async {
      repository.cached = _session();
      await coordinator.restore();

      // A user who taps sign-out on a plane must not stay signed in on the
      // device.
      await coordinator.signOut();

      expect(coordinator.state.isAuthenticated, isFalse);
    });
  });

  group('SessionCapability', () {
    test('exposes the session to other features', () async {
      repository.cached = _session();
      await coordinator.restore();

      expect(coordinator.currentSession, isNotNull);
      expect(coordinator.currentUserId, 'u1');
      expect(coordinator.currentWorkspaceId, 't1');
    });

    test('emits on every session change', () async {
      final sessions = <Session?>[];
      final subscription = coordinator.sessionChanges.listen(sessions.add);

      repository.cached = _session();
      await coordinator.restore();
      await pumpEventQueue();

      await coordinator.signOut();
      await pumpEventQueue();
      await subscription.cancel();

      expect(sessions.length, greaterThanOrEqualTo(2));
      expect(sessions.last, isNull);
    });
  });

  group('state publishing', () {
    test('does not re-emit an identical state', () async {
      final states = <AuthState>[];
      final subscription = coordinator.states.listen(states.add);

      await coordinator.restore();
      await coordinator.restore();
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, hasLength(1));
    });
  });
}
