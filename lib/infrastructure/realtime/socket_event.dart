/// An event pushed by the server.
///
/// The transport hands these up as name + payload and interprets neither. The
/// envelope fields it *does* read are the two the backend puts on every
/// broadcast, because both are transport concerns rather than business ones:
///
/// - [eventId] deduplicates. A reconnect can replay a fact the client already
///   holds, and applying it twice is how an unread count drifts.
/// - [occurredAt] orders. A late broadcast must never overwrite newer state,
///   and arrival order does not survive a reconnect.
///
/// See the backend's `SocketEventEnvelope`.
class SocketEvent {
  const SocketEvent({
    required this.name,
    required this.payload,
    this.eventId,
    this.occurredAt,
  });

  /// Reads the envelope off a decoded frame.
  factory SocketEvent.fromWire(String name, Object? raw) {
    final payload = raw is Map
        ? Map<String, Object?>.from(raw)
        : <String, Object?>{};

    return SocketEvent(
      name: name,
      payload: payload,
      eventId: payload['eventId']?.toString(),
      occurredAt: _parseTime(payload['occurredAt']),
    );
  }

  /// The server's event name (`message.created`).
  final String name;

  final Map<String, Object?> payload;

  /// Stable identity for this fact. Null for the transient events that are
  /// never persisted and so never need deduplicating -- typing, for one.
  final String? eventId;

  /// When the fact happened on the server, in UTC.
  final DateTime? occurredAt;

  /// True when this event can be deduplicated and ordered. A frame without an
  /// envelope must not be written to a store that assumes both.
  bool get isDeduplicable => eventId != null && occurredAt != null;

  static DateTime? _parseTime(Object? raw) {
    if (raw is! String) return null;

    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  String toString() => 'SocketEvent($name, eventId: $eventId)';
}
