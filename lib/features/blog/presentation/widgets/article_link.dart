import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/routes.dart';

/// What happens when a reader taps a link inside an article.
///
/// The design system reports the tap and knows nothing about what an address
/// means (RULE 33 keeps a router out of it); this is where meaning is applied,
/// and it is deliberately narrow about what it will act on.
abstract final class ArticleLink {
  /// The backend writes internal links as `/blog/<slug>`, relative on purpose
  /// so a domain change does not break old articles.
  static const String _blogPrefix = '${AppRoutes.blog}/';

  /// Follows [href], or does nothing when it is not something to follow.
  ///
  /// Three cases, and a deliberate fourth that is refused:
  ///
  /// - another article on this blog opens in the app, replacing the current
  ///   one so a chain of links does not build an unbounded back stack;
  /// - `http`/`https` opens in the browser, because it is somebody else's page
  ///   and the app has nothing to render it with;
  /// - `mailto`/`tel` hand off to the platform, which is what the sanitiser
  ///   allows them for;
  /// - anything else is ignored. A stored article is sanitised on the way in,
  ///   so a scheme that reaches here is either new or a mistake, and following
  ///   an unknown scheme on a reader's behalf is not a decision this should
  ///   make.
  static Future<void> follow(BuildContext context, String href) async {
    final String target = href.trim();

    if (target.isEmpty) return;

    if (target.startsWith(_blogPrefix)) {
      final String slug = target.substring(_blogPrefix.length);

      if (slug.isEmpty) return;

      /*
        `pushReplacement`, so following three links in a row leaves one article
        behind rather than three - the back gesture returns to where the reader
        came from, which is the index.
      */
      context.pushReplacement(
        AppRoutes.blogArticlePath(Uri.decodeComponent(slug)),
      );

      return;
    }

    final Uri? uri = Uri.tryParse(target);

    if (uri == null || !_followable(uri)) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static bool _followable(Uri uri) => switch (uri.scheme) {
    'http' || 'https' || 'mailto' || 'tel' => true,
    _ => false,
  };
}
