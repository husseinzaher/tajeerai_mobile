import 'routes.dart';

/// Turning an address the outside world sent into a route in this app.
///
/// Pure, and deliberately so: a link arrives from a browser, a push
/// notification, a campaign or somebody's WhatsApp message, and what it should
/// open is a decision worth being able to test as a plain function call rather
/// than by launching an activity.
///
/// ## What it will open, and what it refuses
///
/// Only the blog, because the blog is the only thing in this app a stranger
/// with a link is entitled to reach without signing in. Everything else is
/// behind a session, and a deep link into it would be answered by the auth
/// guard anyway - so rather than route to a screen the guard will immediately
/// bounce, an unknown address opens nothing and the app starts normally.
abstract final class DeepLink {
  /// The app's own scheme, which the social sign-in callback also uses.
  ///
  /// The callback is `tajeerai://auth/callback`; these are
  /// `tajeerai://blog/<slug>`. The host is what tells them apart, which is why
  /// the manifest's OAuth filter is scoped to `auth` rather than claiming the
  /// whole scheme.
  static const String scheme = 'tajeerai';

  /// The hosts whose web addresses this app is willing to answer for.
  ///
  /// An allowlist rather than "any https link": the app is only verified for
  /// its own domain, and treating a stranger's `/blog/x` as an instruction
  /// would let any page send a reader wherever it liked inside the app.
  static const Set<String> webHosts = <String>{
    'tajeerai.com',
    'www.tajeerai.com',
  };

  /// The website prefixes a marketing URL carries that this app does not.
  ///
  /// The site is `/ar/blog/<slug>`, because its pages are translated per
  /// locale. The app has one locale at a time and gets it from the member's
  /// own setting, so the segment is read past rather than honoured - opening
  /// an Arabic link does not silently switch an English reader's app.
  static const Set<String> localeSegments = <String>{'ar', 'en'};

  /// The in-app location [uri] names, or null when it names nothing here.
  static String? resolve(Uri uri) {
    if (!_ours(uri)) return null;

    final List<String> segments = _meaningfulSegments(uri);

    if (segments.isEmpty || segments.first != 'blog') return null;

    if (segments.length == 1) return AppRoutes.blog;

    /*
      Already decoded: `Uri.pathSegments` percent-decodes, which is what turns
      `%D9%83%D9%8A%D9%81` back into `كيف`. The route builder encodes it again
      on the way in, so an Arabic address survives the round trip.
    */
    final String slug = segments[1];

    return slug.isEmpty ? AppRoutes.blog : AppRoutes.blogArticlePath(slug);
  }

  /// Whether this address belongs to this app at all.
  static bool _ours(Uri uri) => switch (uri.scheme) {
    scheme => true,
    'https' => webHosts.contains(uri.host.toLowerCase()),
    /*
      Plain `http` is refused even for our own host. A link that arrives
      unencrypted has been readable, and possibly writable, by whatever carried
      it - and there is no article worth opening on those terms when the
      https one is one redirect away.
    */
    _ => false,
  };

  /// The path, with the parts that are the website's business removed.
  ///
  /// For a custom-scheme link the host *is* the first segment
  /// (`tajeerai://blog/x` has host `blog`), which is the one genuinely
  /// confusing thing about custom schemes and the reason this is a method
  /// rather than a field read.
  static List<String> _meaningfulSegments(Uri uri) {
    final List<String> segments = <String>[
      if (uri.scheme == scheme && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((segment) => segment.isNotEmpty).toList();

    if (segments.isNotEmpty && localeSegments.contains(segments.first)) {
      return segments.sublist(1);
    }

    return segments;
  }
}
