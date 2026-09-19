import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/social_sign_in_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/infrastructure/device/google_sign_in/google_sign_in_gateway.dart';
import 'package:tajeerai_mobile/infrastructure/device/web_auth/web_authenticator.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/security/pkce.dart';

import '../domain/fakes/fake_auth_repository.dart';

class _Browser implements WebAuthenticator {
  _Browser(this.answer);

  final Uri? answer;
  Uri? opened;

  @override
  Future<Uri> authenticate({
    required Uri url,
    required String callbackScheme,
  }) async {
    opened = url;

    final Uri? result = answer;

    if (result == null) throw StateError('dismissed');

    return result;
  }
}

class _Google implements GoogleSignInGateway {
  _Google(this.answer);

  final String? answer;
  String? serverClientId;

  @override
  Future<String?> signIn({required String serverClientId}) async {
    this.serverClientId = serverClientId;

    return answer;
  }
}

const Session _session = Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Hussein',
    email: 'husseinzaher@outlook.com',
    role: 'owner',
    locale: 'ar',
    permissions: <String>{'manage:all'},
  ),
);

void main() {
  late FakeAuthRepository repository;

  setUp(() {
    repository = FakeAuthRepository()..socialSession = _session;
  });

  SocialSignInCoordinator coordinatorWith({
    required _Browser browser,
    required _Google google,
  }) {
    return SocialSignInCoordinator(
      repository: repository,
      browser: browser,
      google: google,
      logger: Logger('test', verbose: false),
      pkce: PkceGenerator(random: Random(7)),
    );
  }

  group('Google native sign-in', () {
    test('sends the deployment web client id and posts the id token', () async {
      final _Google google = _Google('google-id-token');

      final SocialSignInOutcome outcome = await coordinatorWith(
        browser: _Browser(null),
        google: google,
      ).signIn(provider: 'google', locale: 'ar');

      expect(outcome, isA<SocialSignedIn>());
      expect((outcome as SocialSignedIn).session, _session);
      expect(google.serverClientId, repository.googleWebClientId);
      expect(repository.googleTokens.single, 'google-id-token:ar');
      expect(repository.exchanged, isEmpty);
    });

    test('reports a dismissed picker as a cancellation', () async {
      final SocialSignInOutcome outcome = await coordinatorWith(
        browser: _Browser(null),
        google: _Google(null),
      ).signIn(provider: 'google', locale: 'ar');

      expect(outcome, isA<SocialSignInCancelled>());
      expect(repository.googleTokens, isEmpty);
    });

    test('passes the server refusal through', () async {
      repository.socialFailure = const AuthenticationFailure(
        message: 'social_email_required',
        sessionExpired: false,
      );

      final SocialSignInOutcome outcome = await coordinatorWith(
        browser: _Browser(null),
        google: _Google('token'),
      ).signIn(provider: 'google', locale: 'ar');

      expect(outcome, isA<SocialSignInRefused>());
      expect((outcome as SocialSignInRefused).reason, 'social_email_required');
    });
  });

  group('Facebook browser sign-in', () {
    test('opens the provider with the challenge, and spends the code with the verifier', () async {
      final _Browser browser = _Browser(
        Uri.parse('tajeerai://auth/callback?code=handoff-code'),
      );

      final SocialSignInOutcome outcome = await coordinatorWith(
        browser: browser,
        google: _Google(null),
      ).signIn(provider: 'facebook', locale: 'ar');

      expect(outcome, isA<SocialSignedIn>());

      final String? challenge =
          browser.opened?.queryParameters['codeChallenge'];
      expect(challenge, isNotNull);

      final String spent = repository.exchanged.single;
      final String verifier = spent.split(':').last;
      expect(PkceGenerator.challengeFor(verifier), challenge);
    });

    test('reports a dismissed browser as a cancellation', () async {
      final SocialSignInOutcome outcome = await coordinatorWith(
        browser: _Browser(null),
        google: _Google(null),
      ).signIn(provider: 'facebook', locale: 'ar');

      expect(outcome, isA<SocialSignInCancelled>());
    });
  });

  test('asks the server which providers to draw', () async {
    repository.providers = const <String>['google', 'facebook'];

    await expectLater(
      coordinatorWith(
        browser: _Browser(null),
        google: _Google(null),
      ).availableProviders(),
      completion(<String>['google', 'facebook']),
    );
  });
}
