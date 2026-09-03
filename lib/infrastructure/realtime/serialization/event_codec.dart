/// Reads the wire format the gateway speaks.
///
/// Knows the transport-level frames -- the two the server sends immediately
/// before closing a socket -- and nothing about business events. Which
/// business names matter is the feature handlers' business; see
/// `features/conversations/realtime/`.
class EventCodec {
  const EventCodec();

  /// `REALTIME_EVENTS.authExpired`. Sent before the server drops a socket
  /// whose token is missing, expired or invalid.
  static const String authExpiredEvent = 'auth.expired';

  /// `REALTIME_EVENTS.accessChanged`. Sent before the server drops a socket
  /// whose member's reach changed.
  static const String accessChangedEvent = 'access.changed';

  /// Socket.IO's own frames, which `onAny` also delivers and which must never
  /// be mistaken for server events.
  static const Set<String> _transportEvents = <String>{
    'connect',
    'connecting',
    'connect_error',
    'connect_timeout',
    'disconnect',
    'error',
    'reconnect',
    'reconnect_attempt',
    'reconnect_error',
    'reconnect_failed',
    'ping',
    'pong',
  };

  /// Whether a frame is handled by the connection's lifecycle path rather than
  /// forwarded as a business event.
  bool isLifecycleEvent(String name) =>
      name == authExpiredEvent ||
      name == accessChangedEvent ||
      _transportEvents.contains(name);

  /// Pulls `reason` off a lifecycle payload.
  String? reasonOf(Object? data) {
    if (data is! Map) return null;

    return data['reason']?.toString();
  }
}
