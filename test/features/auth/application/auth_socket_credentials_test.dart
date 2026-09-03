import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/session_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/application/state/auth_state.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/realtime/auth_socket_credentials.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';

import '../domain/fakes/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late SessionCoordinator coordinator;
  late AuthSocketCredentials credentials;

  setUp(() {
    repository = FakeAuthRepository();

    coordinator = SessionCoordinator(
      authService: AuthService(repository),
      logger: Logger('test', verbose: false),
    );

    credentials = AuthSocketCredentials(
      repository: repository,
      coordinator: coordinator,
      logger: Logger('test', verbose: false),
    );
  });

  tearDown(() => coordinator.dispose());

  test('supplies the stored access token for the handshake', () async {
    expect(await credentials.currentToken(), 'token-1');
  });

  test('reports no token when there is no session', () async {
    repository.token = null;

    expect(await credentials.currentToken(), isNull);
  });

  test('renews the session and returns the new token', () async {
    final token = await credentials.refreshToken();

    expect(token, 'token-2');
    expect(repository.refreshCalls, 1);

    // Still signed in -- a successful refresh must not end the session.
    expect(coordinator.state.status, isNot(AuthStatus.unauthenticated));
  });

  test('ends the session when the credential cannot be renewed', () async {
    repository.refreshedToken = null;

    final token = await credentials.refreshToken();

    // Returning null is what tells the manager to stop retrying. Without a
    // terminal answer the client reconnects forever against a credential the
    // server has already refused.
    expect(token, isNull);
    expect(coordinator.state.status, AuthStatus.unauthenticated);
    expect(coordinator.state.failure, isNotNull);
  });
}
