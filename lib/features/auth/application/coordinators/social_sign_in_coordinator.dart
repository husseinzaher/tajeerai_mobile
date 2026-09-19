import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/device/google_sign_in/google_sign_in_gateway.dart';
import '../../../../infrastructure/device/web_auth/web_authenticator.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/security/pkce.dart';
import '../../domain/entities/social_auth_config.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Signing in with Google or Facebook.
///
/// Google uses the platform SDK and returns an id token the API verifies
/// directly. Facebook still runs the browser redirect with PKCE, because Meta
/// offers no equivalent native token on mobile.
class SocialSignInCoordinator {
  SocialSignInCoordinator({
    required AuthRepository repository,
    required WebAuthenticator browser,
    required GoogleSignInGateway google,
    required Logger logger,
    PkceGenerator pkce = const PkceGenerator(),
  }) : _repository = repository,
       _browser = browser,
       _google = google,
       _logger = logger,
       _pkce = pkce;

  final AuthRepository _repository;
  final WebAuthenticator _browser;
  final GoogleSignInGateway _google;
  final Logger _logger;
  final PkceGenerator _pkce;

  /// The scheme the Android manifest claims for the Facebook browser callback.
  static const String callbackScheme = 'tajeerai';

  /// Which providers to draw buttons for. Never throws - no answer is no
  /// buttons, which is also what an unconfigured deployment looks like.
  Future<List<String>> availableProviders() async {
    final SocialAuthConfig config = await _repository.socialAuthConfig();

    return config.providers;
  }

  /// Runs the round trip and says how it ended.
  Future<SocialSignInOutcome> signIn({
    required String provider,
    required String locale,
  }) async {
    final String normalized = provider.toLowerCase();

    if (normalized == 'google') {
      return _signInWithGoogle(locale: locale);
    }

    return _signInWithBrowser(provider: normalized, locale: locale);
  }

  Future<SocialSignInOutcome> _signInWithGoogle({
    required String locale,
  }) async {
    final SocialAuthConfig config = await _repository.socialAuthConfig();
    final String? serverClientId = config.googleWebClientId;

    if (serverClientId == null || serverClientId.isEmpty) {
      return const SocialSignInRefused(reason: 'social_failed');
    }

    final String? idToken;

    try {
      idToken = await _google.signIn(serverClientId: serverClientId);
    } on Object catch (error, stackTrace) {
      _logger.error(
        'native Google sign-in failed',
        error: error,
        stackTrace: stackTrace,
      );

      return const SocialSignInRefused(reason: 'social_failed');
    }

    if (idToken == null) {
      _logger.info('Google sign-in was dismissed');

      return const SocialSignInCancelled();
    }

    try {
      return SocialSignedIn(
        await _repository.completeNativeGoogleSignIn(
          idToken: idToken,
          locale: locale,
        ),
      );
    } on AuthenticationFailure catch (failure) {
      return SocialSignInRefused(reason: _refusalReason(failure.message));
    }
  }

  Future<SocialSignInOutcome> _signInWithBrowser({
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
      return const SocialSignInRefused(reason: 'social_failed');
    }

    try {
      return SocialSignedIn(
        await _repository.completeSocialSignIn(
          code: code,
          codeVerifier: pair.verifier,
        ),
      );
    } on AuthenticationFailure catch (failure) {
      return SocialSignInRefused(reason: _refusalReason(failure.message));
    }
  }

  static String _refusalReason(String message) {
    if (message.startsWith('social_')) {
      return message;
    }

    return 'social_failed';
  }
}

/// How a social sign-in ended.
sealed class SocialSignInOutcome {
  const SocialSignInOutcome();
}

final class SocialSignedIn extends SocialSignInOutcome {
  const SocialSignedIn(this.session);

  final Session session;
}

final class SocialSignInCancelled extends SocialSignInOutcome {
  const SocialSignInCancelled();
}

final class SocialSignInRefused extends SocialSignInOutcome {
  const SocialSignInRefused({required this.reason});

  final String reason;
}
