/// The application-wide failure taxonomy.
///
/// Every layer speaks this vocabulary. Infrastructure catches its own
/// exception types -- `DioException`, `SocketException`, drift's
/// `SqliteException` -- and translates them here at the data boundary, so a
/// domain service or a controller never has to know which client produced a
/// problem in order to react to it.
///
/// ## Why this is a top-level directory
///
/// It is not `core/` or `shared/` by another name: it has exactly one
/// responsibility, holds no business rules, and is the only thing in the
/// project that every layer may import. It carries no Flutter, Riverpod, Dio,
/// drift or socket dependency -- the Architecture Guard checks that -- which is
/// what lets the framework-free domain layer depend on it. Anything else added
/// here would make it the dumping ground the architecture forbids.
library;

/// A failure the application can reason about.
///
/// Sealed so a handler that switches on it is exhaustive: adding a case here
/// turns every unconsidered call site into a compile error rather than a
/// silent fall-through to "unknown".
sealed class AppFailure implements Exception {
  const AppFailure({required this.message, this.cause});

  /// A short, non-sensitive description. Safe to log; not necessarily safe to
  /// show -- presentation maps a failure to its own copy.
  final String message;

  /// The originating error, kept for logging only. Never rendered.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input the server or a domain rule rejected.
///
/// [fieldErrors] mirrors the backend's `SocketAckError.details` shape --
/// `Record<string, string[]>` -- so a form can attach messages to the fields
/// that produced them instead of showing one banner for all of them.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const <String, List<String>>{},
    super.cause,
  });

  final Map<String, List<String>> fieldErrors;

  List<String> errorsFor(String field) =>
      fieldErrors[field] ?? const <String>[];
}

/// The caller is not signed in, or the session expired.
///
/// Distinct from [AuthorizationFailure] because the remedy differs: this one
/// sends the user to sign in, that one does not.
final class AuthenticationFailure extends AppFailure {
  const AuthenticationFailure({
    required super.message,
    this.sessionExpired = false,
    super.cause,
  });

  /// True when a session existed and stopped being valid, which is worth
  /// telling the user about; false for a rejected sign-in attempt.
  final bool sessionExpired;
}

/// The caller is signed in but may not do this.
final class AuthorizationFailure extends AppFailure {
  const AuthorizationFailure({required super.message, super.cause});
}

/// The thing addressed does not exist, or is no longer visible to the caller.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({required super.message, super.cause});
}

/// The server rejected a command because the state changed underneath it --
/// the backend's `CONFLICT`. Retrying the same command unchanged will fail
/// the same way; the caller has to re-read first.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({required super.message, super.cause});
}

/// The network or an HTTP call failed.
///
/// [isOffline] separates "the device has no connection" from "the server
/// answered badly". Only the first is a normal condition in an offline-first
/// app, and only the second is worth surfacing as an error.
final class TransportFailure extends AppFailure {
  const TransportFailure({
    required super.message,
    this.statusCode,
    this.isOffline = false,
    super.cause,
  });

  final int? statusCode;
  final bool isOffline;
}

/// The server is throttling this client.
///
/// Nothing is wrong with what was asked: waiting [retryAfter] -- or a moment,
/// when the server did not say -- and asking again succeeds. Kept apart from
/// [TransportFailure] so a sync can pace itself instead of reporting an error.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    required super.message,
    this.retryAfter,
    super.cause,
  });

  final Duration? retryAfter;
}

/// The realtime transport failed -- not connected, the command timed out
/// waiting for its acknowledgement, or the socket reported an error.
final class SocketFailure extends AppFailure {
  const SocketFailure({
    required super.message,
    this.code,
    this.isRetryable = true,
    super.cause,
  });

  /// The backend's `SocketErrorCode` when the server answered, null when the
  /// failure happened before a reply arrived.
  final String? code;

  /// Whether sending the same command again could succeed. False for a
  /// rejection the server will repeat -- validation, permissions, conflict.
  final bool isRetryable;
}

/// Local persistence failed. Always a defect or a full disk, never a normal
/// condition, so it is reported rather than retried silently.
final class DatabaseFailure extends AppFailure {
  const DatabaseFailure({required super.message, super.cause});
}

/// Synchronisation could not complete, so local state is behind the server.
///
/// The data on screen stays valid and readable -- this reports staleness, not
/// a broken screen.
final class SynchronizationFailure extends AppFailure {
  const SynchronizationFailure({required super.message, super.cause});
}

/// Anything unclassified. A failure reaching here is a gap in the mapping, so
/// it carries its cause for the log.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    this.message0 = 'An unexpected error occurred.',
    super.cause,
  }) : super(message: message0);

  final String message0;
}

/// Wraps anything that is not already an [AppFailure].
///
/// The last line of a `catch`: it guarantees the layers above only ever see
/// the taxonomy, even for an error nobody anticipated.
AppFailure asAppFailure(Object error, [String? fallbackMessage]) {
  if (error is AppFailure) return error;

  return UnknownFailure(
    message0: fallbackMessage ?? 'An unexpected error occurred.',
    cause: error,
  );
}
