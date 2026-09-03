import '../../domain/entities/user.dart';

/// What other features may know about the signed-in user.
///
/// **This is the only supported way another feature reaches auth.** The
/// Conversations feature needs the current user's id to tell its own messages
/// from a colleague's, and the workspace id to scope its sync -- but it must
/// not import `AuthRepository`, `AuthService`, the auth data layer or an auth
/// screen to get them. It depends on this interface, which says what it needs
/// and nothing about how auth works.
///
/// The architecture guard enforces the boundary (rules 13-15); this interface
/// is what makes obeying it possible rather than merely required.
abstract interface class SessionCapability {
  /// The current session, or null when signed out.
  Session? get currentSession;

  /// Emits on every change, including sign-out.
  Stream<Session?> get sessionChanges;

  /// The signed-in user's id, or null. The common case, so it is spelled out
  /// rather than left as `currentSession?.user.id` at every call site.
  String? get currentUserId;

  /// The workspace id, or null for a session without one.
  String? get currentWorkspaceId;

  /// Ends the session.
  ///
  /// On the contract because signing out is offered from screens the auth
  /// feature does not own -- the Inbox has the button. Exposing it here lets
  /// those screens end a session without importing an auth controller, which
  /// is the feature-boundary violation this interface exists to prevent.
  Future<void> signOut();
}
