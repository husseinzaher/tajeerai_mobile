import '../../domain/entities/user.dart';

/// Things that happen to a session, as facts other parts of the app react to.
///
/// A feature that needs to act when a user signs in -- start a socket, clear a
/// cache, kick off a first sync -- listens for one of these instead of being
/// called directly by auth. That keeps the dependency pointing the right way:
/// auth announces, others subscribe, and auth never learns who is listening.
sealed class AuthEvent {
  const AuthEvent();
}

/// A session was established, by sign-in or by restoring a cached one.
///
/// [wasRestored] separates the two because they warrant different behaviour:
/// a fresh sign-in starts from an empty local database, while a restored
/// session already holds data and needs an incremental catch-up instead of a
/// full first sync.
final class SignedIn extends AuthEvent {
  const SignedIn({required this.session, required this.wasRestored});

  final Session session;
  final bool wasRestored;
}

/// The session ended.
///
/// [wasExpired] distinguishes the user tapping sign-out from the server
/// rejecting the credential. Only the second is worth telling the user about.
final class SignedOut extends AuthEvent {
  const SignedOut({this.wasExpired = false});

  final bool wasExpired;
}

/// The access credential was rotated. The socket reconnects on this; nothing
/// else needs to care.
final class SessionRefreshed extends AuthEvent {
  const SessionRefreshed({required this.session});

  final Session session;
}
