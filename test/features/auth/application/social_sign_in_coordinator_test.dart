import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/application/coordinators/social_sign_in_coordinator.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/infrastructure/device/web_auth/web_authenticator.dart';
import 'package:tajeerai_mobile/infrastructure/logging/logger.dart';
import 'package:tajeerai_mobile/infrastructure/security/pkce.dart';

import '../domain/fakes/fake_auth_repository.dart';

/// A browser that answers with whatever the test says the provider sent back.
class _Browser implements WebAuthenticator {
  _Browser(this.answer);

  /// The callback URL, or null to behave as a dismissed browser does.
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

  SocialSignInCoordinator coordinatorWith(_Browser browser) {
    return SocialSignInCoordinator(
      repository: repository,
      browser: browser,
      logger: Logger('test', verbose: false),
      // Seeded, so the verifier is the same every run and the assertion below
      // is about the flow rather than about randomness.
      pkce: PkceGenerator(random: Random(7)),
    );
  }

  test('opens the provider with the challenge, and spends the code with the verifier', () async {
    final _Browser browser = _Browser(
      Uri.parse('tajeerai://auth/callback?code=handoff-code'),
    );

    final SocialSignInOutcome outcome = await coordinatorWith(browser)
        .signIn(provider: 'google', locale: 'ar');

    expect(outcome, isA<SocialSignedIn>());
    expect((outcome as SocialSignedIn).session, _session);

    // The challenge went out...
    final String? challenge = browser.opened?.queryParameters['codeChallenge'];
    expect(challenge, isNotNull);

    // ...and what came back was spent with the verifier that made it, which is
    // the whole mechanism.
    final String spent = repository.exchanged.single;
    final String verifier = spent.split(':').last;
    expect(PkceGenerator.challengeFor(verifier), challenge);
  });

  test(
    'says the sign-in is for this app, so the callback comes back here',
    () async {
      final _Browser browser = _Browser(
        Uri.parse('tajeerai://auth/callback?code=c'),
      );

      await coordinatorWith(browser).signIn(provider: 'google', locale: 'en');

      expect(browser.opened?.queryParameters['client'], 'mobile');
      expect(browser.opened?.queryParameters['locale'], 'en');
    },
  );

  /*
    Closing the browser is how somebody changes their mind. Reported as an
    outcome rather than an error, so no screen draws a failure for it.
  */
  test(
    'reports a dismissed browser as a cancellation, not a failure',
    () async {
      final SocialSignInOutcome outcome = await coordinatorWith(_Browser(null))
          .signIn(provider: 'google', locale: 'ar');

      expect(outcome, isA<SocialSignInCancelled>());
      expect(repository.exchanged, isEmpty);
    },
  );

  test(
    'passes the server\'s own refusal through, without wording it',
    () async {
      final SocialSignInOutcome outcome = await coordinatorWith(
        _Browser(
          Uri.parse('tajeerai://auth/callback?error=social_email_required'),
        ),
      ).signIn(provider: 'google', locale: 'ar');

      expect(outcome, isA<SocialSignInRefused>());
      expect((outcome as SocialSignInRefused).reason, 'social_email_required');
      expect(repository.exchanged, isEmpty);
    },
  );

  test('refuses a callback carrying neither a code nor a reason', () async {
    final SocialSignInOutcome outcome = await coordinatorWith(
      _Browser(Uri.parse('tajeerai://auth/callback')),
    ).signIn(provider: 'google', locale: 'ar');

    expect(outcome, isA<SocialSignInRefused>());
    expect(repository.exchanged, isEmpty);
  });

  /* A transport problem is a fault, and still travels as one. */
  test('lets a transport failure through', () async {
    repository.socialFailure = const TransportFailure(
      message: 'offline',
      isOffline: true,
    );

    await expectLater(
      coordinatorWith(_Browser(Uri.parse('tajeerai://auth/callback?code=c')))
          .signIn(provider: 'google', locale: 'ar'),
      throwsA(isA<TransportFailure>()),
    );
  });

  test('asks the server which providers to draw', () async {
    repository.providers = const <String>['google', 'facebook'];

    await expectLater(
      coordinatorWith(_Browser(null)).availableProviders(),
      completion(<String>['google', 'facebook']),
    );
  });
}
