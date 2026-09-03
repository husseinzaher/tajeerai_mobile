/// Supplies the token the socket handshake carries.
///
/// An interface rather than a token value, because a socket outlives the
/// credential it opened with. When the server closes a connection with
/// `auth.expired`, the transport asks for a *fresh* token before reconnecting;
/// handing it a string once would have it reconnect forever with the same dead
/// credential.
///
/// The implementation lives in the auth feature, which is the only part of the
/// app that knows how a session is refreshed. Infrastructure stays unaware.
abstract interface class SocketCredentialsProvider {
  /// The token for the next handshake, or null when there is no session.
  Future<String?> currentToken();

  /// Attempts to renew the session after the server rejected the token.
  ///
  /// Returns the new token, or null when the session cannot be recovered --
  /// at which point the transport stops retrying and reports
  /// [SocketConnectionState.unauthenticated] rather than looping.
  Future<String?> refreshToken();
}
