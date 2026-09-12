/// What the deployment exposes for social sign-in.
///
/// Client ids are public; they are compiled into native apps and appear in OAuth
/// redirects. The secret never crosses this boundary.
final class SocialAuthConfig {
  const SocialAuthConfig({
    required this.providers,
    this.googleWebClientId,
  });

  final List<String> providers;

  /// The web OAuth client id Google native sign-in must pass as serverClientId.
  final String? googleWebClientId;
}
