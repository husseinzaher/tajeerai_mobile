import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../display/avatar.dart';
import '../display/relative_time.dart';
import '../localization/ds_localization.dart';
import '../primitives/bidi_text.dart';
import 'message_data.dart';

/// Something the team wrote to itself.
///
/// Amber, like a sticky note, and labelled as internal in its own header -
/// the whole point of the colour is that nobody mistakes it for a message the
/// customer received. The same card the web's inbox draws, at the width a
/// phone has.
class AppInternalNoteCard extends StatelessWidget {
  const AppInternalNoteCard({required this.entry, this.now, super.key});

  final AppRecordEntryData entry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return _RecordCard(
      background: colors.warningSoft,
      border: colors.warningBorder,
      chipBackground: colors.warningSoft,
      chipForeground: colors.warningForeground,
      chipIcon: LucideIcons.messageSquareText,
      chipLabel: context.strings.internalNote,
      entry: entry,
      now: now,
    );
  }
}

/// The assistant's summary of the thread so far.
///
/// Tinted with the primary colour and marked with a sparkle, so it reads as
/// the product speaking rather than a member - and because it is the one
/// entry a reader scrolls back to find.
class AppSummaryCard extends StatelessWidget {
  const AppSummaryCard({required this.entry, this.now, super.key});

  final AppRecordEntryData entry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return _RecordCard(
      background: colors.primarySoft,
      border: colors.primaryBorder,
      chipBackground: colors.primarySoft,
      chipForeground: colors.primary,
      chipIcon: LucideIcons.sparkles,
      chipLabel: context.strings.conversationSummary,
      entry: entry,
      now: now,
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.background,
    required this.border,
    required this.chipBackground,
    required this.chipForeground,
    required this.chipIcon,
    required this.chipLabel,
    required this.entry,
    required this.now,
  });

  final Color background;
  final Color border;
  final Color chipBackground;
  final Color chipForeground;
  final IconData chipIcon;
  final String chipLabel;
  final AppRecordEntryData entry;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final String author = entry.authorName ?? context.strings.systemAuthor;
    final String locale =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.xs,
      ),
      child: Semantics(
        label: chipLabel,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            TajeerSpacing.sm,
            TajeerSpacing.sm,
            TajeerSpacing.sm,
            TajeerSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: TajeerRadii.lgAll,
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TajeerSpacing.xs,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TajeerSpacing.xs,
                  vertical: TajeerSpacing.xs2 / 2,
                ),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: TajeerRadii.fullAll,
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TajeerSpacing.xs2,
                  children: <Widget>[
                    Icon(chipIcon, size: 12, color: chipForeground),
                    // Flexible: the chip sits in a card as narrow as the
                    // phone makes it, and "ملخص المحادثة" at a large text
                    // size is wider than that. It shortens rather than
                    // spilling over the card's own edge.
                    Flexible(
                      child: Text(
                        chipLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.labelSm.copyWith(
                          color: chipForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.text case final String text when text.isNotEmpty)
                AppBidiText(
                  text,
                  style: context.type.bodyMd.copyWith(
                    color: colors.textPrimary,
                    height: 1.6,
                  ),
                ),
              Row(
                spacing: TajeerSpacing.xs,
                children: <Widget>[
                  AppAvatar(name: author, size: 20),
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${AppRelativeTime.clock(entry.at, locale: locale)}, '
                      '${AppRelativeTime.forDay(entry.at, locale: locale, messages: context.strings, now: now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
