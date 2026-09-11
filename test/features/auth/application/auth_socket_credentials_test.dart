import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/auth/realtime/auth_socket_credentials.dart';
import 'package:tajeerai_mobile/infrastructure/network/token_refresher.dart';

import '../domain/fakes/fake_auth_repository.dart';

/// A renewer that counts, and answers what the test sets.
class _CountingRenewer implements CredentialRenewer {
  RefreshOutcome outcome = const TokenRefreshed('token-2');
  int calls = 0;

  @override
  Future<RefreshOutcome> renew() async {
    calls += 1;

    return outcome;
  }
}

void main() {
  late FakeAuthRepository repository;
  late _CountingRenewer renewer;
  late AuthSocketCredentials credentials;

  setUp(() {
    repository = FakeAuthRepository();
    renewer = _CountingRenewer();

    credentials = AuthSocketCredentials(
      repository: repository,
      refresher: TokenRefresher(renewer),
    );
  });

  test('supplies the stored access token for the handshake', () async {
    expect(await credentials.currentToken(), 'token-1');
  });

  test('reports no token when there is no session', () async {
    repository.token = null;

    expect(await credentials.currentToken(), isNull);
  });

  test(
    'renews through the shared refresher and passes the outcome on',
    () async {
      expect(await credentials.refreshToken(), isA<TokenRefreshed>());

      renewer.outcome = const RefreshRejected();
      expect(await credentials.refreshToken(), isA<RefreshRejected>());

      renewer.outcome = const RefreshUnavailable();
      expect(await credentials.refreshToken(), isA<RefreshUnavailable>());

      expect(renewer.calls, 3);
    },
  );

  test('a reconnect arriving mid-renewal does not renew twice', () async {
    final List<RefreshOutcome> outcomes = await Future.wait(
      <Future<RefreshOutcome>>[
        credentials.refreshToken(),
        credentials.refreshToken(),
      ],
    );

    // The backend's refresh tokens are single-use: a second renewal would
    // spend a token the first had already revoked.
    expect(renewer.calls, 1);
    expect(outcomes, everyElement(isA<TokenRefreshed>()));
  });
}
