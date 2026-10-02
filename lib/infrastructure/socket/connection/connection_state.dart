/// The transport's connection state.
///
/// Deliberately separate from synchronisation state. "Connected" says a socket
/// is open; it says nothing about whether the local database has caught up
/// with what happened while it was closed. Conflating the two is what makes a
/// client show stale data with a reassuring green dot -- see
/// `SynchronizationState`, which is tracked independently.
enum SocketConnectionState {
  /// No socket, and none being opened. The resting state before sign-in and
  /// after sign-out.
  disconnected,

  /// A first connection attempt is in flight.
  connecting,

  /// Open and authenticated.
  connected,

  /// The connection dropped and is being re-established on a backoff.
  ///
  /// Distinct from [connecting] because the client already holds data: the UI
  /// keeps showing it rather than falling back to a first-run empty state.
  reconnecting,

  /// The server rejected the credentials. Terminal until a new token arrives;
  /// retrying with the same one would loop against the same rejection.
  unauthenticated;

  bool get isConnected => this == SocketConnectionState.connected;

  /// Whether a command may be attempted. Only a live socket qualifies -- the
  /// outbox holds everything else rather than firing into a closed pipe.
  bool get canSend => isConnected;

  /// Whether the client is actively trying to get back.
  bool get isTransient =>
      this == SocketConnectionState.connecting ||
      this == SocketConnectionState.reconnecting;
}
