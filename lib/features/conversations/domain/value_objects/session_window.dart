/// The state of WhatsApp's 24-hour customer service window, as the server
/// answered it.
///
/// Three facts, all of them the server's. **This app owns none of the rule.**
/// It does not know that the window is twenty-four hours long, which channels
/// have one at all, or that it runs from the customer's last inbound message
/// rather than from the last message in the thread. It renders what it was
/// told and counts towards the instant it was given.
///
/// That is deliberate, and the backend says so where it resolves the window:
/// every client would otherwise re-implement "last inbound plus 24 hours,
/// unless this channel has no window", and the copy that drifted would be the
/// one deciding whether the composer is usable.
///
/// ## Why the composer bothers, when the server refuses anyway
///
/// The send is refused server-side whatever this says, and that is the
/// enforcement. This is the difference between being told before you type and
/// being told afterwards: without it the member writes a message, taps send,
/// and finds it sitting in the thread as a failure somebody now has to clear.
final class SessionWindow {
  const SessionWindow({
    this.lastCustomerMessageAt,
    this.expiresAt,
    this.isOpenPerServer,
  });

  /// A conversation the server said nothing about.
  ///
  /// Distinct from a closed window: nothing is claimed, so nothing is blocked.
  /// A channel with no window at all, and a server too old to report one, are
  /// both this.
  static const SessionWindow unreported = SessionWindow();

  /// When the customer last wrote in. Null when they never have.
  final DateTime? lastCustomerMessageAt;

  /// When a free-form message stops being allowed. Null when nothing expires.
  final DateTime? expiresAt;

  /// The server's verdict at the moment it answered.
  ///
  /// Null means it did not answer - see [unreported].
  final bool? isOpenPerServer;

  /// Whether the server reported a window for this conversation at all.
  bool get isReported => isOpenPerServer != null;

  /// Whether a free-form message is refused right now.
  ///
  /// The server's verdict, plus the server's own expiry once it passes. The
  /// second part is not a second rule: a thread left open on a phone holds an
  /// answer that was true when it was fetched, and [expiresAt] is the moment
  /// the server already said it stops being true. Without it the composer
  /// stays enabled until something syncs, and the member finds out by having
  /// a message refused.
  bool isClosed(DateTime now) {
    if (isOpenPerServer == false) {
      return true;
    }

    if (isOpenPerServer == null) {
      return false;
    }

    final DateTime? expiry = expiresAt;

    return expiry != null && !now.isBefore(expiry);
  }

  /// How long is left, or null once there is nothing left.
  ///
  /// Null rather than [Duration.zero] so a caller draws the expired state
  /// rather than "0 minutes remaining", which reads as a bug.
  Duration? remaining(DateTime now) {
    final DateTime? expiry = expiresAt;

    if (expiry == null) {
      return null;
    }

    final Duration left = expiry.difference(now);

    return left > Duration.zero ? left : null;
  }

  SessionWindow copyWith({
    DateTime? lastCustomerMessageAt,
    DateTime? expiresAt,
    bool? isOpenPerServer,
  }) {
    return SessionWindow(
      lastCustomerMessageAt:
          lastCustomerMessageAt ?? this.lastCustomerMessageAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isOpenPerServer: isOpenPerServer ?? this.isOpenPerServer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionWindow &&
          other.lastCustomerMessageAt == lastCustomerMessageAt &&
          other.expiresAt == expiresAt &&
          other.isOpenPerServer == isOpenPerServer;

  @override
  int get hashCode =>
      Object.hash(lastCustomerMessageAt, expiresAt, isOpenPerServer);
}
