import 'package:google_sign_in/google_sign_in.dart';

/// Obtains a Google id token from the platform's native sign-in UI.
///
/// Google refuses OAuth inside a WebView (`disallowed_useragent`), and a Custom
/// Tab is still the web consent screen. Play Services and the iOS SDK are the
/// app-native path: one tap, the account picker the person already knows, and
/// an id token whose audience is the deployment's web client id.
abstract interface class GoogleSignInGateway {
  /// Resolves with an id token, or null when the person dismissed the picker.
  Future<String?> signIn({required String serverClientId});
}

/// The platform implementation backed by `google_sign_in`.
class PlatformGoogleSignInGateway implements GoogleSignInGateway {
  const PlatformGoogleSignInGateway();

  @override
  Future<String?> signIn({required String serverClientId}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      serverClientId: serverClientId,
    );

    final GoogleSignInAccount? account = await googleSignIn.signIn();

    if (account == null) {
      return null;
    }

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In returned no id token.');
    }

    return idToken;
  }
}
