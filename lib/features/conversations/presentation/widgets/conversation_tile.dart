import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../../../app/theme/theme.dart';
import '../../domain/entities/conversation.dart';

/// One row in the Inbox rail.
///
/// A feature widget, not a design-system one: it knows what a conversation is.
/// It is *composed* from design-system parts -- [AppAvatar], [AppBadge],
/// [AppPressable] -- and introduces no colour or spacing of its own.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conversation,
    required this.onTap,
    this.isSelected = false,
    super.key,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  /// Highlighted on a tablet, where the rail and the thread are side by side.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = conversation.hasUnread;

    return AppPressable(
      onTap: onTap,
      borderRadius: TajeerRadii.lgAll,
      semanticLabel: _semanticLabel(),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TajeerSpacing.md,
          vertical: TajeerSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primarySoft : Colors.transparent,
          borderRadius: TajeerRadii.lgAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            AppAvatar(
              name: conversation.displayName,
              imageUrl: conversation.customerAvatarUrl,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: TajeerSpacing.xs2,
                children: <Widget>[
                  Row(
                    spacing: TajeerSpacing.xs,
                    children: <Widget>[
                      if (conversation.isPinned)
                        Icon(
                          LucideIcons.pin,
                          size: 12,
                          color: colors.textMuted,
                        ),
                      Expanded(
                        child: Text(
                          conversation.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            // An unread thread is bolder, not a different
                            // colour: colour is already carrying the badge.
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        formatTimestamp(
                          conversation.lastMessageAt ?? conversation.createdAt,
                        ),
                        style: context.text.bodySmall?.copyWith(
                          color: unread ? colors.primary : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: TajeerSpacing.xs,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ?? 'No messages yet',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      if (unread)
                        AppBadge(label: '${conversation.unreadCount}'),
                      if (conversation.isMuted)
                        Icon(
                          LucideIcons.bellOff,
                          size: 12,
                          color: colors.textMuted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One sentence for a screen reader, instead of five disconnected fragments.
  String _semanticLabel() {
    final parts = <String>[
      conversation.displayName,
      if (conversation.hasUnread)
        '${conversation.unreadCount} unread messages'
      else
        'no unread messages',
      if (conversation.lastMessagePreview != null)
        conversation.lastMessagePreview!,
    ];

    return parts.join(', ');
  }

  /// Time today, weekday this week, date beyond that.
  ///
  /// The rail is scanned, not read: a full date on every row is noise when
  /// most threads are from the last hour.
  static String formatTimestamp(DateTime timestamp, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final local = timestamp.toLocal();
    final difference = current.difference(local);

    if (difference.inDays == 0 && current.day == local.day) {
      return DateFormat.jm().format(local);
    }

    if (difference.inDays < 7) return DateFormat.E().format(local);

    return DateFormat.yMd().format(local);
  }
}
