import '../entities/user.dart';

/// What renewing a session came to.
///
/// A result rather than a nullable token, because "could not renew" is two
/// different facts. The server refusing the refresh credential ends the
/// session; being offline, throttled or answered with a server error does not,
/// and a client that cannot tell the two apart signs members out whenever the
/// network blinks.
sealed class SessionRenewal {
  const SessionRenewal();
}

/// The session was renewed, and the renewed copy -- with whatever permissions
/// the server now grants -- is stored.
final class SessionRenewed extends SessionRenewal {
  const SessionRenewed({required this.session, required this.accessToken});

  final Session session;
  final String accessToken;
}

/// The server refused the refresh credential. Signing in again is the only way
/// back.
final class SessionRenewalRejected extends SessionRenewal {
  const SessionRenewalRejected();
}

/// The renewal could not be attempted or finished. The session stands.
final class SessionRenewalUnavailable extends SessionRenewal {
  const SessionRenewalUnavailable();
}
