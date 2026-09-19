import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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

/// The Android OAuth client id, compiled in from [androidClientIdFromEnvironment].
///
/// Public, like a package name — it identifies the app to Google, not a secret.
/// Create an OAuth client of type "Android" in Google Cloud Console and register
/// package `com.tajeerai.mobile` with your keystore SHA-1 (`make google-android-sha1`).
const String googleAndroidClientId = String.fromEnvironment(
  'TAJEER_GOOGLE_ANDROID_CLIENT_ID',
);

/// The iOS OAuth client id, compiled in from [iosClientIdFromEnvironment].
///
/// Public, like a bundle id — it identifies the app to Google, not a secret.
/// Run `make google-sign-in-setup` after setting it in `.env`.
const String googleIosClientId = String.fromEnvironment(
  'TAJEER_GOOGLE_IOS_CLIENT_ID',
);

/// The platform implementation backed by `google_sign_in`.
class PlatformGoogleSignInGateway implements GoogleSignInGateway {
  const PlatformGoogleSignInGateway();

  @override
  Future<String?> signIn({required String serverClientId}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: const <String>['email', 'profile'],
      clientId: nativeClientIdFromEnvironment(),
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

/// Resolves the Android client id when this build targets Android.
String? androidClientIdFromEnvironment() {
  if (kIsWeb || !Platform.isAndroid) {
    return null;
  }

  final String trimmed = googleAndroidClientId.trim();

  return trimmed.isEmpty ? null : trimmed;
}

/// Resolves the iOS client id when this build targets iOS.
String? iosClientIdFromEnvironment() {
  if (kIsWeb || !Platform.isIOS) {
    return null;
  }

  final String trimmed = googleIosClientId.trim();

  return trimmed.isEmpty ? null : trimmed;
}

/// The platform-native OAuth client id, when one was compiled in.
String? nativeClientIdFromEnvironment() {
  return androidClientIdFromEnvironment() ?? iosClientIdFromEnvironment();
}
