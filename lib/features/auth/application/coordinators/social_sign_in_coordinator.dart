import '../../../../infrastructure/device/web_auth/web_authenticator.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/security/pkce.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Signing in with Google or Facebook.
///
/// ## The shape of it, and why it has this many steps
///
/// A browser finishes a social sign-in by having cookies set on it. This app
/// cannot be finished that way: the sign-in happens in a Custom Tab, whose
/// cookie jar is the browser's and not ours. So the round trip ends with the
/// server handing back a **code**, on a URL that Android routes to whichever
/// app claimed `tajeerai://` - which may not be this one.
///
/// PKCE is what makes that safe. This app invents a verifier, sends only its
/// hash to start with, and must produce the verifier itself to spend the code.
/// An app that intercepted the redirect holds something it cannot use.
///
///     pair = verifier + challenge
///       -> open the browser at /social/<provider>/start?codeChallenge=…
///       -> the person signs in with the provider
///       -> the browser lands on tajeerai://auth/callback?code=…
///       -> exchange(code, verifier) -> a session, exactly as a password
///          sign-in produces one
///
/// Nothing here interprets a provider. Which ones exist is the server's
/// answer, and this passes the name through.
class SocialSignInCoordinator {
  SocialSignInCoordinator({
    required AuthRepository repository,
    required WebAuthenticator browser,
    required Logger logger,
    PkceGenerator pkce = const PkceGenerator(),
  }) : _repository = repository,
       _browser = browser,
       _logger = logger,
       _pkce = pkce;

  final AuthRepository _repository;
  final WebAuthenticator _browser;
  final Logger _logger;
  final PkceGenerator _pkce;

  /// The scheme the Android manifest claims, and the one the API redirects to.
  static const String callbackScheme = 'tajeerai';

  /// Which providers to draw buttons for. Never throws - no answer is no
  /// buttons, which is also what an unconfigured deployment looks like.
  Future<List<String>> availableProviders() => _repository.socialProviders();

  /// Runs the round trip and says how it ended.
  ///
  /// An outcome rather than an exception for the two endings that are not
  /// faults - somebody changed their mind, or the server refused for a reason
  /// it named. A transport failure still throws, because that is one.
  Future<SocialSignInOutcome> signIn({
    required String provider,
    required String locale,
  }) async {
    final PkcePair pair = _pkce.create();

    final Uri start = _repository.socialSignInUrl(
      provider: provider,
      codeChallenge: pair.challenge,
      locale: locale,
    );

    final Uri callback;

    try {
      callback = await _browser.authenticate(
        url: start,
        callbackScheme: callbackScheme,
      );
    } on Object {
      // Dismissing the browser is the ordinary way to change your mind, and
      // the plugin reports it as an exception like any other. It is not a
      // failure worth a red message.
      _logger.info('social sign-in was dismissed');

      return const SocialSignInCancelled();
    }

    final String? error = callback.queryParameters['error'];

    if (error != null) {
      _logger.info(
        'social sign-in refused',
        data: <String, Object?>{'reason': error},
      );

      return SocialSignInRefused(reason: error);
    }

    final String? code = callback.queryParameters['code'];

    if (code == null || code.isEmpty) {
      // A callback with neither a code nor a reason. Nothing to spend and
      // nothing to explain, so it is reported as the refusal it amounts to.
      return const SocialSignInRefused(reason: 'social_failed');
    }

    return SocialSignedIn(
      await _repository.completeSocialSignIn(
        code: code,
        codeVerifier: pair.verifier,
      ),
    );
  }
}

/// How a social sign-in ended.
///
/// Results rather than exceptions, for the reason the API models the same
/// thing this way: neither a changed mind nor a named refusal is a fault, and
/// an exception would make the screen treat them as one.
sealed class SocialSignInOutcome {
  const SocialSignInOutcome();
}

final class SocialSignedIn extends SocialSignInOutcome {
  const SocialSignedIn(this.session);

  final Session session;
}

/// The browser was closed before the provider answered. Nothing went wrong.
final class SocialSignInCancelled extends SocialSignInOutcome {
  const SocialSignInCancelled();
}

/// The server refused, and said which way.
///
/// [reason] is the API's own short code (`social_email_required` and the
/// rest); presentation turns it into words. A sentence built here would arrive
/// in whichever language this layer happened to think in.
final class SocialSignInRefused extends SocialSignInOutcome {
  const SocialSignInRefused({required this.reason});

  final String reason;
}
