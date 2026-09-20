/// How synchronisation is going, independent of whether a socket is open.
///
/// The two are deliberately separate concerns. "Connected" is about a TCP
/// connection; "synchronized" is about whether this device has caught up with
/// what happened on the server. A client can be connected and stale (it just
/// reconnected and has not run its catch-up yet), or disconnected and
/// perfectly current (it synced a second before the tunnel).
///
/// Showing a green dot for the first case is the bug this type exists to
/// prevent.
enum SyncPhase {
  /// Nothing in flight. Says nothing about freshness -- read `syncedAt`.
  idle,

  /// A pass is running.
  syncing,

  /// Caught up as of `syncedAt`.
  synchronized,

  /// Readable but known to be behind.
  stale,

  /// The last pass failed. The data on screen is still valid.
  failed,
}

/// The Inbox's synchronisation state.
final class ConversationSyncState {
  const ConversationSyncState({
    this.phase = SyncPhase.idle,
    this.syncedAt,
    this.pendingMutations = 0,
    this.failedMutations = 0,
    this.message,
    this.hasFailedAttempt = false,
  });

  final SyncPhase phase;

  /// When the server last confirmed this client was current.
  final DateTime? syncedAt;

  /// Mutations waiting to reach the server. Drives "sending…" in the UI.
  final int pendingMutations;

  /// Mutations that gave up. Drives the retry affordance.
  final int failedMutations;

  /// A non-sensitive description of the last failure.
  final String? message;

  /// Whether a pass has finished without catching up, at any point.
  ///
  /// Distinct from `phase == failed`, which does not survive the next thing
  /// that happens: a failed first pass followed by the connection dropping
  /// moves the phase to `stale`, and the rail read "still waiting for the
  /// first pass" forever -- an endless skeleton with no error, no banner and
  /// nothing to retry. This is the fact that does not get overwritten.
  final bool hasFailedAttempt;

  bool get isSyncing => phase == SyncPhase.syncing;

  bool get isBehind => phase == SyncPhase.stale || phase == SyncPhase.failed;

  bool get hasQueuedWork => pendingMutations > 0 || failedMutations > 0;

  /// Whether the data on screen is old enough to warn about.
  ///
  /// Five minutes is a judgement, not a rule from anywhere: long enough that a
  /// brief tunnel does not nag, short enough that an operator does not reply
  /// to a customer based on a stale thread.
  bool isStaleAt(
    DateTime now, {
    Duration threshold = const Duration(minutes: 5),
  }) {
    if (phase == SyncPhase.syncing) return false;

    final last = syncedAt;

    if (last == null) return true;

    return now.difference(last) > threshold;
  }

  ConversationSyncState copyWith({
    SyncPhase? phase,
    DateTime? syncedAt,
    int? pendingMutations,
    int? failedMutations,
    String? message,
    bool clearMessage = false,
    bool? hasFailedAttempt,
  }) {
    return ConversationSyncState(
      phase: phase ?? this.phase,
      syncedAt: syncedAt ?? this.syncedAt,
      pendingMutations: pendingMutations ?? this.pendingMutations,
      failedMutations: failedMutations ?? this.failedMutations,
      message: clearMessage ? null : (message ?? this.message),
      hasFailedAttempt: hasFailedAttempt ?? this.hasFailedAttempt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConversationSyncState &&
      other.phase == phase &&
      other.syncedAt == syncedAt &&
      other.pendingMutations == pendingMutations &&
      other.failedMutations == failedMutations &&
      other.message == message &&
      other.hasFailedAttempt == hasFailedAttempt;

  @override
  int get hashCode => Object.hash(
    phase,
    syncedAt,
    pendingMutations,
    failedMutations,
    message,
    hasFailedAttempt,
  );
}
