import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/application/events/auth_events.dart';
import 'package:tajeerai_mobile/features/auth/application/state/auth_state.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/session_renewal.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/network/token_refresher.dart';

import '../domain/fakes/fake_auth_repository.dart';

Session _session({Set<String> permissions = const <String>{}}) => Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
    permissions: permissions,
  ),
  workspace: const Workspace(
    id: 't1',
    name: 'Demo',
    slug: 'demo',
    locale: 'ar',
  ),
);

void main() {
  late FakeAuthRepository repository;
  late SessionCoordinator coordinator;

  setUp(() async {
    repository = FakeAuthRepository()..cached = _session();

    coordinator = SessionCoordinator(
      authService: AuthService(repository),
      logger: Logger('test', verbose: false),
    );

    // Signed in from the cache, as a cold start is.
    await coordinator.restore();
  });

  tearDown(() => coordinator.dispose());

  group('renew', () {
    test('publishes the renewed session and hands back its token', () async {
      final Session renewed = _session(permissions: <String>{'read:Customer'});
      repository.renewedSession = renewed;
      final Future<AuthEvent> announced = coordinator.events.firstWhere(
        (AuthEvent event) => event is SessionRefreshed,
      );

      final RefreshOutcome outcome = await coordinator.renew();

      expect(
        outcome,
        isA<TokenRefreshed>().having(
          (TokenRefreshed refreshed) => refreshed.accessToken,
          'accessToken',
          'token-2',
        ),
      );
      // A permission granted since sign-in reaches the screens with the
      // renewal, not at the next restart.
      expect(coordinator.state.session, same(renewed));
      expect(await announced, isA<SessionRefreshed>());
    });

    test('a refusal ends the session and says why', () async {
      repository.nextRenewal = const SessionRenewalRejected();

      expect(await coordinator.renew(), isA<RefreshRejected>());
      expect(coordinator.state.status, AuthStatus.unauthenticated);
      expect(
        coordinator.state.failure,
        isA<AuthenticationFailure>().having(
          (AuthenticationFailure failure) => failure.sessionExpired,
          'sessionExpired',
          isTrue,
        ),
      );
    });

    test(
      'a renewal that could not be asked keeps the member signed in',
      () async {
        repository.nextRenewal = const SessionRenewalUnavailable();

        expect(await coordinator.renew(), isA<RefreshUnavailable>());
        expect(coordinator.state.isAuthenticated, isTrue);
        expect(repository.signOutCalls, 0);
      },
    );

    test('an unexpected error is unavailable, never a sign-out', () async {
      repository.renewalError = StateError('the database is locked');

      expect(await coordinator.renew(), isA<RefreshUnavailable>());
      expect(coordinator.state.isAuthenticated, isTrue);
    });

    test(
      'renewals arriving together through the refresher happen once',
      () async {
        final TokenRefresher refresher = TokenRefresher(coordinator);

        final List<RefreshOutcome> outcomes = await Future.wait(
          <Future<RefreshOutcome>>[
            refresher.refresh(),
            refresher.refresh(),
            refresher.refresh(),
          ],
        );

        expect(repository.refreshCalls, 1);
        expect(outcomes, everyElement(isA<TokenRefreshed>()));
      },
    );
  });

  group('reloadSession', () {
    test('publishes the session the server has now', () async {
      final Session reread = _session(permissions: <String>{'read:Order'});
      repository.nextRestored = reread;

      await coordinator.reloadSession();

      expect(coordinator.state.session, same(reread));
    });

    test('leaves the session alone when the server cannot be asked', () async {
      final Session? before = coordinator.state.session;
      repository.nextRestored = null;

      await coordinator.reloadSession();

      expect(coordinator.state.session, same(before));
    });

    test('reloads asked for together share one read', () async {
      repository.nextRestored = _session();

      await Future.wait(<Future<void>>[
        coordinator.reloadSession(),
        coordinator.reloadSession(),
      ]);

      expect(repository.restoreCalls, 1);
    });

    test('does nothing while signed out', () async {
      await coordinator.signOut();
      final int before = repository.restoreCalls;

      await coordinator.reloadSession();

      expect(repository.restoreCalls, before);
    });
  });
}
