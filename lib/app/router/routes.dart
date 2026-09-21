/// Every route in the application, in one place.
///
/// Paths as constants rather than string literals at call sites: a typo in a
/// literal is a runtime 404 on a user's device, while a typo here does not
/// compile. Feature route *names* are prefixed with the feature that owns
/// them, which is what keeps route ownership legible as the app grows.
abstract final class AppRoutes {
  // Unauthenticated.
  static const String login = '/login';

  /// The blog: public content, readable without a session.
  ///
  /// The first product screen in this app a guest may open. It sits outside the
  /// signed-in shell deliberately - the shell assumes a session to draw its
  /// profile and its permission-filtered tabs - so the blog is a top-level
  /// route reachable in either state, and a signed-in member reaches it from
  /// the drawer rather than a fourth tab.
  static const String blog = '/blog';

  /// One article, addressed by the slug the website uses.
  ///
  /// The same slug, so a link shared from the site opens the same article here:
  /// `/blog/how-to-connect-whatsapp`. Arabic slugs are percent-encoded in a URL
  /// and decoded back by the router, which is what lets an Arabic article keep
  /// an Arabic address.
  static const String blogArticle = ':slug';

  /// The full path, for pushing from anywhere and for a deep link.
  static String blogArticlePath(String slug) =>
      '$blog/${Uri.encodeComponent(slug)}';

  // Authenticated.
  static const String conversations = '/conversations';

  /// The thread. Nested under the rail so the platform back gesture returns
  /// there rather than exiting the app.
  static const String conversationDetail = 'thread/:conversationId';

  /// The full path, for pushing from anywhere.
  static String conversationDetailPath(String conversationId) =>
      '$conversations/thread/$conversationId';

  /// The workspace's contacts.
  static const String customers = '/customers';

  /// One contact. Nested under the list so the platform back gesture returns
  /// there rather than exiting the app.
  static const String customerDetail = ':customerId';
  static const String customerNew = 'new';

  /// Writing an entry on a contact's record. Nested under the contact, because
  /// that is where it is reached from and where it returns to.
  static const String customerNoteNew = 'notes/new';

  static String customerDetailPath(String customerId) =>
      '$customers/$customerId';

  static String customerNewPath() => '$customers/new';

  static String customerNoteNewPath(String customerId) =>
      '$customers/$customerId/notes/new';

  /// The member's own settings: account, appearance, language, the way out.
  static const String settings = '/settings';
  static const String callerIdSettings = 'caller-id';
  static String callerIdSettingsPath() => '$settings/$callerIdSettings';

  /// The design system's own documentation surface.
  ///
  /// Registered only under `kDebugMode`, so it never ships to a merchant. The
  /// route constant is unconditional because `AuthGuard` must stay free of
  /// build-mode branching — in a release build there is simply nothing at the
  /// other end of it.
  static const String designSystem = '/design-system';

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
  static const String blog = 'blog';
  static const String blogArticle = 'blog-article';
  static const String conversations = 'conversations';
  static const String conversationDetail = 'conversation-detail';
  static const String customers = 'customers';
  static const String customerDetail = 'customer-detail';
  static const String customerNew = 'customer-new';
  static const String customerNoteNew = 'customer-note-new';
  static const String settings = 'settings';
  static const String callerIdSettings = 'caller-id-settings';
  static const String designSystem = 'design-system';
  static const String splash = 'splash';
}
