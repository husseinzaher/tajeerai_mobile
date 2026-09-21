import '../value_objects/session_window.dart';

/// Where a conversation sits in its lifecycle. Mirrors the backend's
/// `ConversationState`.
enum ConversationState { open, pending, closed, archived }

/// A thread with a customer.
///
/// The domain's own shape -- not a database row and not a socket payload. Both
/// of those are translated into this at the data boundary, which is what lets
/// the rules below be tested without either.
final class Conversation {
  const Conversation({
    required this.id,
    required this.state,
    required this.createdAt,
    this.channelId,
    this.customerId,
    this.customerName,
    this.customerAvatarUrl,
    this.assigneeId,
    this.subject,
    this.unreadCount = 0,
    this.failedMessageCount = 0,
    this.tags = const <String>[],
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastInboundMessageAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.isBotEnabled = false,
    this.sessionWindow = SessionWindow.unreported,
    this.updatedAt,
  });

  final String id;
  final ConversationState state;
  final String? channelId;
  final String? customerId;
  final String? customerName;
  final String? customerAvatarUrl;
  final String? assigneeId;
  final String? subject;
  final int unreadCount;

  /// Messages the server could not send, as the server counts them.
  ///
  /// A failed send used to be invisible from the rail: the alert said a
  /// message had failed and nothing said which thread. On WhatsApp the usual
  /// cause is the 24-hour window closing, which is exactly when the answer is
  /// worth having quickly.
  final int failedMessageCount;
  final List<String> tags;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? lastInboundMessageAt;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final bool isBotEnabled;

  /// WhatsApp's 24-hour window, exactly as the server reported it.
  ///
  /// Carried rather than computed: which channels have a window, and how long
  /// it runs, are the server's rules and not this app's. A conversation the
  /// server said nothing about holds [SessionWindow.unreported], which blocks
  /// nothing.
  final SessionWindow sessionWindow;

  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasUnread => unreadCount > 0;

  bool get hasFailedMessages => failedMessageCount > 0;

  /// What the rail shows as the thread's name.
  ///
  /// "Unknown customer" is a presentation fallback the backend explicitly says
  /// is never stored as the name -- so it is derived here, never persisted.
  String get displayName {
    final name = customerName?.trim();

    if (name != null && name.isNotEmpty) return name;

    final threadSubject = subject?.trim();

    if (threadSubject != null && threadSubject.isNotEmpty) return threadSubject;

    return 'Unknown customer';
  }

  /// Whether a new message may be added to this thread.
  ///
  /// **The rule.** An archived thread is closed to new traffic: archiving is
  /// the workspace's decision that the conversation is done, and letting a
  /// message into it would resurrect a thread every agent has stopped
  /// watching. A `closed` thread is *not* covered -- the backend reopens one
  /// on a new message (`conversation:reopen` exists for exactly that), so
  /// refusing here would break a supported flow.
  bool get acceptsNewMessages =>
      !isArchived && state != ConversationState.archived;

  Conversation copyWith({
    ConversationState? state,
    int? unreadCount,
    int? failedMessageCount,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
    bool? isArchived,
    bool? isPinned,
    bool? isMuted,
  }) {
    return Conversation(
      id: id,
      state: state ?? this.state,
      channelId: channelId,
      customerId: customerId,
      customerName: customerName,
      customerAvatarUrl: customerAvatarUrl,
      assigneeId: assigneeId,
      subject: subject,
      unreadCount: unreadCount ?? this.unreadCount,
      failedMessageCount: failedMessageCount ?? this.failedMessageCount,
      tags: tags,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastInboundMessageAt: lastInboundMessageAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isBotEnabled: isBotEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Conversation &&
      other.id == id &&
      other.state == state &&
      other.unreadCount == unreadCount &&
      other.failedMessageCount == failedMessageCount &&
      other.lastMessageAt == lastMessageAt &&
      other.isArchived == isArchived &&
      other.isPinned == isPinned;

  @override
  int get hashCode => Object.hash(
    id,
    state,
    unreadCount,
    failedMessageCount,
    lastMessageAt,
    isArchived,
    isPinned,
  );
}
