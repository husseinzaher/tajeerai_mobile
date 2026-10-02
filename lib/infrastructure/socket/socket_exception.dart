import '../../failures/app_failure.dart';

/// The realtime transport's own error type.
///
/// Confined to `infrastructure/realtime/` and the feature realtime handlers
/// that translate it. [toFailure] is the boundary: nothing above the data
/// layer sees this class.
class SocketException implements Exception {
  const SocketException({
    required this.message,
    this.code,
    this.details,
    this.cause,
  });

  /// The command never got an acknowledgement in time.
  ///
  /// Retryable by construction: the server may well have applied it, which is
  /// exactly why every command that mutates carries a client-generated
  /// idempotency key.
  const SocketException.timeout(String command)
    : message = 'The server did not answer "$command" in time.',
      code = 'TIMEOUT',
      details = null,
      cause = null;

  /// A command was issued while the socket was down.
  const SocketException.disconnected(String command)
    : message = 'Not connected; "$command" was not sent.',
      code = 'DISCONNECTED',
      details = null,
      cause = null;

  final String message;

  /// The backend's `SOCKET_ERROR_CODES` value, or one of the transport-local
  /// codes above.
  final String? code;

  /// Field-level messages from `SocketAckError.details`.
  final Map<String, List<String>>? details;

  final Object? cause;

  /// Whether re-sending the identical command could succeed.
  ///
  /// The four rejections the server will simply repeat are excluded;
  /// everything else -- a timeout, a dropped connection, an upstream outage,
  /// a rate limit -- is worth another attempt, which is what makes the outbox
  /// able to decide retry versus fail without a second table of rules.
  bool get isRetryable => switch (code) {
    'VALIDATION_FAILED' || 'FORBIDDEN' || 'NOT_FOUND' || 'CONFLICT' => false,
    _ => true,
  };

  /// Maps this onto the application-wide taxonomy.
  AppFailure toFailure() {
    return switch (code) {
      'UNAUTHENTICATED' => AuthenticationFailure(
        message: message,
        sessionExpired: true,
        cause: cause,
      ),
      'FORBIDDEN' => AuthorizationFailure(message: message, cause: cause),
      'NOT_FOUND' => NotFoundFailure(message: message, cause: cause),
      'CONFLICT' => ConflictFailure(message: message, cause: cause),
      'VALIDATION_FAILED' => ValidationFailure(
        message: message,
        fieldErrors: details ?? const <String, List<String>>{},
        cause: cause,
      ),
      _ => SocketFailure(
        message: message,
        code: code,
        isRetryable: isRetryable,
        cause: cause,
      ),
    };
  }
}
