/// Every route in the application, in one place.
///
/// Paths as constants rather than string literals at call sites: a typo in a
/// literal is a runtime 404 on a user's device, while a typo here does not
/// compile. Feature route *names* are prefixed with the feature that owns
/// them, which is what keeps route ownership legible as the app grows.
abstract final class AppRoutes {
  // Unauthenticated.
  static const String login = '/login';

  // Authenticated.
  static const String conversations = '/conversations';

  /// The thread. Nested under the rail so the platform back gesture returns
  /// there rather than exiting the app.
  static const String conversationDetail = 'thread/:conversationId';

  /// The full path, for pushing from anywhere.
  static String conversationDetailPath(String conversationId) =>
      '$conversations/thread/$conversationId';

  /// Shown while the session is still being resolved at start-up.
  ///
  /// A real route, not a flag: without it the router would have to guess, and
  /// routing on "not authenticated" during that window flashes the login
  /// screen at an already-signed-in user on every cold start.
  static const String splash = '/';
}

/// Named routes, for `goNamed` and for deep links.
abstract final class AppRouteNames {
  static const String login = 'login';
  static const String conversations = 'conversations';
  static const String conversationDetail = 'conversation-detail';
  static const String splash = 'splash';
}
