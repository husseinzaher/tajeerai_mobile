import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../display/relative_time.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/bidi_text.dart';
import '../primitives/pressable.dart';
import 'message_data.dart';
import 'message_status_icon.dart';

/// One message in a thread.
///
/// Outgoing sits at the end edge on the brand wash; incoming at the start edge
/// on a card. The corner nearest the speaker is tightened — the tail, without
/// drawing one — and so is the join between two bubbles of one run. The
/// corners are logical, so Arabic mirrors without a second layout. That corner
/// logic came across from the feature's bubble unchanged: it is the one piece
/// of subtle direction handling in the thread, and rewriting it was risk for
/// nothing.
///
/// The words keep their own direction, so an English reply in an Arabic thread
/// still ends with its question mark. A failed message is outlined in danger
/// and offers retry and discard as buttons — the links they replace were brand
/// yellow on a light surface, at 1.5:1.
class AppMessageBubble extends StatelessWidget {
  const AppMessageBubble({
    required this.message,
    this.startsRun = true,
    this.endsRun = true,
    this.onRetry,
    this.onDiscard,
    this.onLongPress,
    super.key,
  });

  final AppMessageData message;

  /// The first bubble of a run from one author. Only the first names who wrote
  /// it, and only the first keeps its rounded corner on the speaker's side.
  final bool startsRun;

  /// The last of its run. Only the last carries the time — unless the message
  /// has something to say about its delivery, which every bubble does.
  final bool endsRun;

  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  final VoidCallback? onLongPress;

  /// How much of the thread's width a bubble may take. Wider than this a
  /// message is hard to read and hides which side it came from.
  static const double maxWidthFactor = 0.78;

  /// The corners for one bubble.
  static BorderRadiusDirectional radiusFor({
    required bool outgoing,
    required bool startsRun,
  }) {
    const Radius round = Radius.circular(TajeerRadii.lg);
    const Radius tight = Radius.circular(TajeerRadii.sm);
    final Radius joined = startsRun ? round : tight;

    return outgoing
        ? BorderRadiusDirectional.only(
            topStart: round,
            bottomStart: round,
            topEnd: joined,
            bottomEnd: tight,
          )
        : BorderRadiusDirectional.only(
            topStart: joined,
            bottomStart: tight,
            topEnd: round,
            bottomEnd: round,
          );
  }

  /// Delivery states worth a line under every bubble, not only the last.
  static bool _speaksUp(AppMessageStatus status) => switch (status) {
    AppMessageStatus.queued ||
    AppMessageStatus.sending ||
    AppMessageStatus.notSent ||
    AppMessageStatus.removed => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final bool outgoing = message.side == AppMessageSide.outgoing;
    final String time = AppRelativeTime.clock(
      message.sentAt,
      locale: Localizations.maybeLocaleOf(context)?.languageCode ?? 'en',
    );
    final String? author = startsRun
        ? message.authorName ?? (message.isFromBot ? strings.bot : null)
        : null;
    final BorderRadiusDirectional radius = radiusFor(
      outgoing: outgoing,
      startsRun: startsRun,
    );
    final Color edge = message.status == AppMessageStatus.notSent
        ? colors.dangerDefault
        : outgoing
        ? Colors.transparent
        : context.elevation.card.hairline;

    return Align(
      alignment: outgoing
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * maxWidthFactor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: outgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          spacing: TajeerSpacing.xs2,
          children: <Widget>[
            if (author != null)
              ExcludeSemantics(
                child: Wrap(
                  spacing: TajeerSpacing.xs2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (message.isFromBot)
                      Icon(LucideIcons.bot, size: 12, color: colors.textMuted),
                    Text(
                      author,
                      style: context.type.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            AppPressable(
              onLongPress: onLongPress,
              borderRadius: radius,
              scaleOnPress: false,
              semanticLabel: _sentence(strings, author, time),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: TajeerSpacing.sm,
                  vertical: TajeerSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: outgoing
                      ? colors.primarySoft
                      : context.elevation.card.tone,
                  borderRadius: radius,
                  border: Border.fromBorderSide(BorderSide(color: edge)),
                ),
                child: _Content(message: message),
              ),
            ),
            if (endsRun || _speaksUp(message.status))
              ExcludeSemantics(
                // Wraps rather than overflows: at large text the time and a
                // worded status do not fit on one line of a bubble.
                child: Wrap(
                  spacing: TajeerSpacing.xs2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      time,
                      style: context.type.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    if (outgoing) AppMessageStatusIcon(status: message.status),
                  ],
                ),
              ),
            if (message.canRetry && (onRetry != null || onDiscard != null))
              Wrap(
                spacing: TajeerSpacing.xs,
                children: <Widget>[
                  if (onRetry != null)
                    AppButton(
                      label: strings.retry,
                      onPressed: onRetry,
                      variant: AppButtonVariant.link,
                      size: AppButtonSize.small,
                    ),
                  if (onDiscard != null)
                    AppButton(
                      label: strings.discard,
                      onPressed: onDiscard,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// One sentence for a screen reader: who, what, when, and how it went.
  String _sentence(AppMessages strings, String? author, String time) =>
      <String?>[
        author,
        _Content.describe(message, strings),
        time,
        if (message.side == AppMessageSide.outgoing)
          AppMessageStatusIcon.labelFor(message.status, strings),
      ].whereType<String>().join(', ');
}

/// What is inside a bubble.
///
/// Media draws as a labelled line for now — a picture's thumbnail, a voice
/// note's player and a file's card are the next milestone's — so a message the
/// app can name is never an empty bubble, and one it cannot is never a crash.
class _Content extends StatelessWidget {
  const _Content({required this.message});

  final AppMessageData message;

  static (IconData, String)? _media(AppMessageKind kind, AppMessages strings) =>
      switch (kind) {
        AppMessageKind.image => (LucideIcons.image, strings.photo),
        AppMessageKind.video => (LucideIcons.video, strings.video),
        AppMessageKind.audio => (LucideIcons.mic, strings.voiceMessage),
        AppMessageKind.document => (LucideIcons.fileText, strings.document),
        AppMessageKind.location => (LucideIcons.mapPin, strings.location),
        AppMessageKind.text ||
        AppMessageKind.system ||
        AppMessageKind.unsupported => null,
      };

  /// The bubble, in words.
  static String describe(AppMessageData message, AppMessages strings) {
    final (IconData, String)? media = _media(message.kind, strings);
    final String? text = message.text;
    if (message.kind == AppMessageKind.unsupported) {
      return strings.unsupportedMessage;
    }
    if (media != null) {
      return text == null ? media.$2 : '${media.$2}, $text';
    }
    return text ?? strings.unsupportedMessage;
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final TextStyle words = context.type.bodyLg.copyWith(
      color: colors.textPrimary,
    );
    final (IconData, String)? media = _media(message.kind, strings);
    final String? text = message.text;

    if (message.kind == AppMessageKind.unsupported ||
        (media == null && text == null)) {
      return Text(
        strings.unsupportedMessage,
        style: words.copyWith(color: colors.textMuted),
      );
    }
    if (media == null) {
      return AppBidiText(text!, style: words);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TajeerSpacing.xs2,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            Icon(media.$1, size: 18, color: colors.textSecondary),
            Flexible(
              child: Text(
                media.$2,
                style: context.type.labelMd.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (text != null) AppBidiText(text, style: words),
      ],
    );
  }
}
