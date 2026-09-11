import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../channels/channel_glyph.dart';
import '../display/avatar.dart';
import '../display/badge.dart';
import '../display/list_item.dart';
import '../display/relative_time.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
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
          Flexible(child: _Line(summary.title)),
        ],
      ),
      meta: time == null ? null : Text(time),
      subtitle: summary.preview == null ? null : _Line(summary.preview!),
      trailing: summary.hasUnread || summary.isMuted
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
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

/// A line of somebody else's words, read in its own direction.
///
/// A row's title and preview are written by customers, in whatever language
/// they wrote in. Laid out in the Inbox's direction, an English question in an
/// Arabic Inbox reads "?before it ships": the punctuation takes the paragraph's
/// side. So the line keeps its own direction, found from its words, and stays
/// aligned to the row's start edge either way.
class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr,
    textAlign: Directionality.of(context) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left,
  );
}
