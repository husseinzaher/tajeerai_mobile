/// What renewing the session's credential came to.
///
/// Three outcomes, not two. A renewal that could not be *attempted* -- no
/// network, the server throttling, a server error -- says nothing about whether
/// the session is still good, and treating it like a refusal signs a member
/// out in a lift. Only [RefreshRejected] ends a session.
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// A new access credential, already stored where both transports read it.
final class TokenRefreshed extends RefreshOutcome {
  const TokenRefreshed(this.accessToken);

  final String accessToken;
}

/// The server refused the refresh credential. The session is over.
final class RefreshRejected extends RefreshOutcome {
  const RefreshRejected();
}

/// The renewal could not be attempted or finished. The session stands, and
/// asking again later may succeed.
final class RefreshUnavailable extends RefreshOutcome {
  const RefreshUnavailable();
}

/// Renews the credential.
///
/// Implemented by the auth feature, the only part of the app that knows what a
/// session is. The transports depend on this interface and on nothing of auth.
abstract interface class CredentialRenewer {
  Future<RefreshOutcome> renew();
}

/// Shares one renewal between everything that needs one.
///
/// The backend's refresh tokens are single-use: `JwtTokenIssuer.rotate()`
/// revokes the token it is handed before issuing the next. A socket reconnect
/// and an HTTP retry renewing independently at the same moment would send the
/// same refresh token twice, and whichever arrived second -- its token already
/// revoked -- would be told the session is over. So a caller that finds a
/// renewal in flight waits for that one instead of starting its own.
class TokenRefresher {
  TokenRefresher(this._renewer);

  final CredentialRenewer _renewer;

  Future<RefreshOutcome>? _inFlight;

  Future<RefreshOutcome> refresh() {
    final Future<RefreshOutcome>? running = _inFlight;
    if (running != null) return running;

    final Future<RefreshOutcome> renewal = _renewer.renew().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = renewal;

    return renewal;
  }
}
