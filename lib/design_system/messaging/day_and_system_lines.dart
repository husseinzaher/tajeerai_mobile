import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../display/labelled_separator.dart';
import '../display/relative_time.dart';
import '../localization/ds_localization.dart';
import '../primitives/bidi_text.dart';

/// Where a day starts in a thread: "Today", "Yesterday", or a date.
///
/// A heading to a screen reader, so a member can move through a long thread by
/// day instead of message by message.
class AppDateSeparator extends StatelessWidget {
  const AppDateSeparator({required this.day, this.now, super.key});

  final DateTime day;

  /// What "today" is. See `AppConversationListItem.now`.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
        child: AppLabelledSeparator(
          label: AppRelativeTime.forDay(
            day,
            locale: Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
            messages: context.strings,
            now: now,
          ),
        ),
      ),
    );
  }
}

/// A line about the conversation rather than in it — an assignment, a
/// handover to the bot.
///
/// Centred and quiet, never a bubble: it belongs to neither side, and drawing
/// it as one would make it look like somebody said it.
class AppSystemMessage extends StatelessWidget {
  const AppSystemMessage({required this.text, this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: TajeerSpacing.sm,
            vertical: TajeerSpacing.xs2,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: TajeerRadii.fullAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: TajeerSpacing.xs,
            children: <Widget>[
              if (icon != null) Icon(icon, size: 14, color: colors.textMuted),
              Flexible(
                child: AppBidiText(
                  text,
                  textAlign: TextAlign.center,
                  style: context.type.labelSm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
