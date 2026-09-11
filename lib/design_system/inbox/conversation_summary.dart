import 'package:flutter/foundation.dart';

import '../channels/channel_descriptor.dart';
import '../display/status_dot.dart';

/// One conversation, as the Inbox draws it.
///
/// Presentation data, not the domain's `Conversation`. The design system may
/// not import a feature (RULE 18), and it has no reason to want to: a row needs
/// a name to show, a line to preview, a time and a count — already decided,
/// already translated, already fallen back — and none of the rules that
/// produced them. The feature maps into this; the design system draws it.
@immutable
class AppConversationSummary {
  const AppConversationSummary({
    required this.id,
    required this.title,
    this.preview,
    this.lastActivityAt,
    this.unreadCount = 0,
    this.avatarUrl,
    this.presence = AppPresence.unknown,
    this.channel,
    this.isPinned = false,
    this.isMuted = false,
  });

  final String id;

  /// Who the conversation is with, already resolved: the customer's name, or
  /// whatever the app falls back to when there is none.
  final String title;

  /// The last message, or the app's own words for a thread with none. Null
  /// draws no second line at all.
  final String? preview;

  final DateTime? lastActivityAt;
  final int unreadCount;
  final String? avatarUrl;
  final AppPresence presence;

  /// Which channel it arrived on, drawn on the avatar's corner. Null until the
  /// app knows — the conversation payload carries only a channel id today.
  final AppChannelDescriptor? channel;

  final bool isPinned;
  final bool isMuted;

  bool get hasUnread => unreadCount > 0;

  @override
  bool operator ==(Object other) =>
      other is AppConversationSummary &&
      other.id == id &&
      other.title == title &&
      other.preview == preview &&
      other.lastActivityAt == lastActivityAt &&
      other.unreadCount == unreadCount &&
      other.avatarUrl == avatarUrl &&
      other.presence == presence &&
      other.channel == channel &&
      other.isPinned == isPinned &&
      other.isMuted == isMuted;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    preview,
    lastActivityAt,
    unreadCount,
    avatarUrl,
    presence,
    channel,
    isPinned,
    isMuted,
  );
}
