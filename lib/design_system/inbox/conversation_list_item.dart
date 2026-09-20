import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../channels/channel_glyph.dart';
import '../display/avatar.dart';
import '../display/badge.dart';
import '../display/list_item.dart';
import '../display/relative_time.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/bidi_text.dart';
import 'conversation_summary.dart';

/// One row of the Inbox.
///
/// Built on [AppListItem], so it inherits the row the rest of the app uses —
/// the start-edge selection marker, the unread emphasis, the 64px floor —
/// instead of deciding them again. What it adds is a conversation's shape: the
/// avatar carries the channel, the title line carries the time, and the end of
/// the row carries the count.
///
/// **Unread is weight and a count, never a colour on text.** The row this
/// replaced drew its timestamp in the brand yellow, which is 1.53:1 on white.
class AppConversationListItem extends StatelessWidget {
  const AppConversationListItem({
    required this.conversation,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.now,
    super.key,
  });

  final AppConversationSummary conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// On a tablet, where the rail and the thread sit side by side.
  final bool selected;

  /// What "today" is. The clock by default; the showcase and the tests pass
  /// one, so a row does not change with the calendar.
  final DateTime? now;

  static const double avatarSize = 48;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final AppConversationSummary summary = conversation;
    final DateTime? at = summary.lastActivityAt;
    final String? time = at == null
        ? null
        : AppRelativeTime.forRow(
            at,
            locale: Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
            messages: strings,
            now: now,
          );

    return AppListItem(
      leading: AppAvatar(
        name: summary.title,
        imageUrl: summary.avatarUrl,
        size: avatarSize,
        presence: summary.presence,
        badge: summary.channel == null
            ? null
            : AppChannelGlyph(
                kind: summary.channel!.kind,
                size: 12,
                contained: true,
              ),
      ),
      title: Row(
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          if (summary.isPinned)
            Icon(LucideIcons.pin, size: 12, color: colors.textMuted),
          Flexible(child: AppBidiText(summary.title, alignToAmbient: true)),
        ],
      ),
      meta: time == null ? null : Text(time),
      subtitle: summary.preview == null
          ? null
          : AppBidiText(summary.preview!, alignToAmbient: true),
      trailing: summary.hasUnread || summary.hasFailed || summary.isMuted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
                // Above the unread count, and in the destructive colour with
                // its own glyph: the two numbers mean opposite things, and a
                // member scanning the rail has to tell them apart without
                // stopping to read either.
                if (summary.hasFailed)
                  AppBadge(
                    label: summary.failedCount > 99
                        ? '99+'
                        : '${summary.failedCount}',
                    variant: AppBadgeVariant.destructive,
                    size: AppBadgeSize.small,
                    leading: const Icon(LucideIcons.triangleAlert, size: 10),
                  ),
                if (summary.hasUnread) AppBadge.count(summary.unreadCount),
                if (summary.isMuted)
                  Icon(LucideIcons.bellOff, size: 14, color: colors.textMuted),
              ],
            )
          : null,
      emphasised: summary.hasUnread,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: _sentence(strings, time),
    );
  }

  /// One sentence for a screen reader, in reading order, instead of the six
  /// fragments the row is drawn from.
  String _sentence(AppMessages strings, String? time) {
    final AppConversationSummary summary = conversation;
    return <String?>[
      summary.title,
      summary.channel?.title,
      if (summary.hasFailed)
        AppMessages.interpolate(strings.failedCount, <String, Object?>{
          'count': summary.failedCount,
        }),
      if (summary.hasUnread)
        AppMessages.interpolate(strings.unreadCount, <String, Object?>{
          'count': summary.unreadCount,
        }),
      if (summary.isPinned) strings.pinned,
      if (summary.isMuted) strings.muted,
      summary.preview,
      time,
    ].whereType<String>().join(', ');
  }
}
