import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Opens a URL in the system browser and waits for it to come back.
///
/// A social sign-in has to happen in a real browser, not a WebView: Google
/// refuses OAuth in an embedded one (`disallowed_useragent`), and a WebView
/// would also mean this app could read what somebody types into a password
/// field that is not ours. A Custom Tab is the platform's answer - the
/// browser's own process, the browser's own cookies, and the app only ever
/// sees the redirect at the end.
///
/// An interface rather than a direct call, so the flow above it is testable
/// without a platform channel and the plugin stays in infrastructure.
abstract interface class WebAuthenticator {
  /// Opens [url] and resolves with the callback URL the browser was sent to.
  ///
  /// Throws when the person dismisses the browser without finishing.
  Future<Uri> authenticate({required Uri url, required String callbackScheme});
}

/// The platform's own implementation.
class PlatformWebAuthenticator implements WebAuthenticator {
  const PlatformWebAuthenticator();

  @override
  Future<Uri> authenticate({
    required Uri url,
    required String callbackScheme,
  }) async {
    final String result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: callbackScheme,
      // The system browser, not a webview: see the interface.
      options: const FlutterWebAuth2Options(useWebview: false),
    );

    return Uri.parse(result);
  }
}
