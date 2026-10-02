import '../../failures/app_failure.dart';

/// The HTTP transport's own error type.
///
/// Never escapes `infrastructure/network/`: the data layer catches it and
/// translates with [toFailure], so no repository, service, controller or
/// widget ever imports Dio's exception type. That translation is the whole
/// reason this class exists rather than letting `DioException` travel.
class HttpException implements Exception {
  const HttpException({
    required this.message,
    this.statusCode,
    this.body,
    this.isConnectionError = false,
    this.isTimeout = false,
    this.retryAfter,
    this.cause,
  });

  final String message;
  final int? statusCode;

  /// The decoded response body, when there was one. Used to lift the
  /// backend's field-level validation messages out of a 400/422.
  final Object? body;

  /// True when no connection to a server could be made -- DNS, no route, a
  /// connection that would not open.
  final bool isConnectionError;

  /// True when a server was reached but did not answer in time.
  ///
  /// Not "offline". Telling a member on full signal that they have no
  /// connection sends them looking for a problem their phone does not have.
  final bool isTimeout;

  /// How long the server asked the client to wait before trying again, from a
  /// 429's `Retry-After`.
  final Duration? retryAfter;

  final Object? cause;

  /// Maps this onto the application-wide taxonomy.
  ///
  /// The status codes follow the backend's own vocabulary: it answers 401 for
  /// an unauthenticated caller, 403 for a forbidden one, 409 for a conflicting
  /// command, and 400/422 with a `{message, errors}` body for validation.
  AppFailure toFailure() {
    if (isConnectionError) {
      return TransportFailure(
        message: 'Could not reach the server.',
        isOffline: true,
        cause: cause,
      );
    }

    if (isTimeout) {
      return TransportFailure(
        message: 'The server took too long to answer.',
        cause: cause,
      );
    }

    return switch (statusCode) {
      401 => AuthenticationFailure(
        message: message,
        sessionExpired: true,
        cause: cause,
      ),
      403 => AuthorizationFailure(message: message, cause: cause),
      404 => NotFoundFailure(message: message, cause: cause),
      409 => ConflictFailure(message: message, cause: cause),
      400 || 422 => ValidationFailure(
        message: message,
        fieldErrors: _fieldErrors(),
        cause: cause,
      ),
      429 => RateLimitedFailure(
        message: message,
        retryAfter: retryAfter,
        cause: cause,
      ),
      _ => TransportFailure(
        message: message,
        statusCode: statusCode,
        cause: cause,
      ),
    };
  }

  /// Lifts `{ errors: { field: [messages] } }` out of the response body.
  ///
  /// Shaped by the backend's `ZodValidationPipe`, which reports field errors
  /// the same way over HTTP as `SocketAckError.details` does over the socket.
  Map<String, List<String>> _fieldErrors() {
    final payload = body;
    if (payload is! Map) return const <String, List<String>>{};

    final errors = payload['errors'] ?? payload['details'];
    if (errors is! Map) return const <String, List<String>>{};

    return errors.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((entry) => entry.toString()).toList(growable: false)
            : <String>[value.toString()],
      ),
    );
  }
}
