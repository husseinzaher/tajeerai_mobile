import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import '../../infrastructure/logging/logger.dart';
import 'deep_link.dart';

/// Opens what an incoming link names.
///
/// Two ways a link arrives, and both matter: the app was *launched* by one, or
/// it was already running when one was tapped. Handling only the second is the
/// common bug - the link works while you are testing and does nothing from a
/// cold start, which is the case every real reader hits.
///
/// Composition rather than logic: what an address means is
/// [DeepLink.resolve]'s decision, and this only carries the answer to the
/// router.
class DeepLinkListener {
  DeepLinkListener({
    required GoRouter router,
    required Logger logger,
    AppLinks? links,
  }) : _router = router,
       _logger = logger,
       _links = links ?? AppLinks();

  final GoRouter _router;
  final Logger _logger;
  final AppLinks _links;

  StreamSubscription<Uri>? _subscription;

  /// Begins listening, and opens the link the app was launched with, if any.
  ///
  /// Never throws. A malformed address, or a platform that answers the initial
  /// link with an error, must leave the app starting normally rather than
  /// failing to start at all.
  Future<void> start() async {
    _subscription ??= _links.uriLinkStream.listen(
      _open,
      onError: (Object error) => _logger.debug(
        'A deep link could not be read',
        data: <String, Object?>{'error': error.toString()},
      ),
    );

    try {
      final Uri? initial = await _links.getInitialLink();

      if (initial != null) _open(initial);
    } on Object catch (error) {
      _logger.debug(
        'The launch link could not be read',
        data: <String, Object?>{'error': error.toString()},
      );
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _open(Uri uri) {
    final String? location = DeepLink.resolve(uri);

    if (location == null) {
      /*
        Ignored rather than reported. A link this app does not answer for is
        ordinary - a marketing page, a pricing link, somebody else's site - and
        an error for each one would be noise in the log of every install.
      */
      _logger.debug(
        'A link named nothing in this app',
        data: <String, Object?>{'scheme': uri.scheme, 'host': uri.host},
      );

      return;
    }

    _logger.info(
      'Opening a deep link',
      data: <String, Object?>{'location': location},
    );

    /*
      `go`, not `push`: a link replaces where the reader is rather than piling
      on top of it, so tapping three shared articles does not build a back
      stack the reader never navigated.
    */
    _router.go(location);
  }
}
