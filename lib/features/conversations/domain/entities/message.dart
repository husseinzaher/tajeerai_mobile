/// Which way a message travelled.
enum MessageDirection { inbound, outbound }

/// A message's delivery state.
///
/// The first three exist only on this device. A message is real to the user
/// the instant they send it, long before any server has heard of it, and the
/// UI has to say which of those two worlds a message is in.
enum MessageState {
  /// Written locally, queued in the outbox. Survives a restart.
  pending,

  /// The send command is in flight.
  sending,

  /// The send failed; retryable.
  failed,

  /// The server accepted it.
  sent,

  delivered,
  read,

  /// Never accepted, or revoked.
  discarded;

  /// Whether the server has this message.
  bool get isConfirmed => switch (this) {
    MessageState.sent || MessageState.delivered || MessageState.read => true,
    _ => false,
  };

  /// Whether it is still on its way out.
  bool get isInFlight =>
      this == MessageState.pending || this == MessageState.sending;

  /// Whether the UI should offer a retry.
  bool get canRetry => this == MessageState.failed;

  /// Whether [other] is a forward move from this state.
  ///
  /// Delivery states only advance. WhatsApp receipts arrive out of order often
  /// enough that without this a `read` message flips back to `delivered` when
  /// the older receipt lands a moment later.
  bool canAdvanceTo(MessageState other) {
    if (this == other) return false;
    if (other == MessageState.failed) return true;
    if (other == MessageState.discarded) return true;

    return _rank(other) > _rank(this);
  }

  /// The further-along of two delivery states.
  MessageState prefer(MessageState other) {
    if (canAdvanceTo(other)) return other;
    if (other.canAdvanceTo(this)) return this;

    return this;
  }

  static int _rank(MessageState state) => switch (state) {
    MessageState.pending => 0,
    MessageState.sending => 1,
    MessageState.failed => 1,
    MessageState.sent => 2,
    MessageState.delivered => 3,
    MessageState.read => 4,
    MessageState.discarded => 5,
  };
}

/// One message in a thread.
final class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.direction,
    required this.state,
    required this.createdAt,
    this.clientMessageId,
    this.type = 'text',
    this.body,
    this.mediaUrl,
    this.localMediaPath,
    this.authorName,
    this.authorId,
    this.isFromBot = false,
    this.failureReason,
    this.externalId,
    this.updatedAt,
    this.deliveredAt,
    this.readAt,
    this.queuedAt,
  });

  final String id;
  final String conversationId;

  /// The idempotency key for an outbound message, reused across every retry so
  /// a resend after a lost acknowledgement cannot create a duplicate. Null on
  /// inbound messages.
  final String? clientMessageId;

  final MessageDirection direction;
  final MessageState state;
  final String type;
  final String? body;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? authorName;
  final String? authorId;
  final bool isFromBot;
  final String? failureReason;
  final String? externalId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? queuedAt;

  bool get isOutbound => direction == MessageDirection.outbound;

  bool get isInbound => direction == MessageDirection.inbound;

  /// Whether this message was composed on this device and is not yet settled.
  /// Drives the "sending"/"failed" affordances.
  bool get isOptimistic => isOutbound && !state.isConfirmed;

  /// Whether the app can render the content at all.
  ///
  /// The provider's type vocabulary grows server-side, so an unknown type has
  /// to degrade to a placeholder rather than crash a list.
  bool get isRenderable => type == 'text' || body != null || mediaUrl != null;

  Message copyWith({
    String? id,
    MessageState? state,
    String? externalId,
    String? failureReason,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      direction: direction,
      state: state ?? this.state,
      type: type,
      body: body,
      mediaUrl: mediaUrl,
      localMediaPath: localMediaPath,
      authorName: authorName,
      authorId: authorId,
      isFromBot: isFromBot,
      failureReason: failureReason ?? this.failureReason,
      externalId: externalId ?? this.externalId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      queuedAt: queuedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.state == state &&
      other.body == body &&
      other.deliveredAt == deliveredAt &&
      other.readAt == readAt;

  @override
  int get hashCode => Object.hash(id, state, body, deliveredAt, readAt);
}
