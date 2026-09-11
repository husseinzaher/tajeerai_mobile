import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../display/status_dot.dart';
import 'channel_descriptor.dart';
import 'channel_glyph.dart';

/// How loudly a badge names its channel.
enum AppChannelBadgeEmphasis {
  /// A dot beside the name. The quiet default, for a header or a picker, where
  /// the channel is already the one thing on screen.
  dot,

  /// A tinted pill, for a rail an agent scans at speed for "which number is
  /// this", where a dot alone is too easy to miss.
  pill,
}

/// Which channel something belongs to, on one line: "WhatsApp · Sales".
///
/// **The text is never drawn in the channel's colour.** The web draws it that
/// way, and most of the ten instance colours fall below body-text contrast on
/// one theme or the other — a phone in daylight is where that fails first.
/// Here the colour travels in the dot and in the tint behind the text, the
/// text stays ink, and the glyph still says which kind of channel it is.
class AppChannelBadge extends StatelessWidget {
  const AppChannelBadge({
    required this.channel,
    this.emphasis = AppChannelBadgeEmphasis.dot,
    this.showGlyph = true,
    super.key,
  });

  final AppChannelDescriptor channel;
  final AppChannelBadgeEmphasis emphasis;

  /// Off where the kind is already drawn beside the badge.
  final bool showGlyph;

  /// How much of the channel colour the pill is washed with. Low enough that
  /// ink keeps body-text contrast on it for every palette colour, in every
  /// preset and both themes — which a test holds it to.
  static const double tintAlpha = 0.14;

  /// The pill's fill: the channel colour, washed over the surface.
  static Color tintFor(Color channel, Color surface) =>
      Color.alphaBlend(channel.withValues(alpha: tintAlpha), surface);

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final Color? instance = channel.color;
    final bool pill = emphasis == AppChannelBadgeEmphasis.pill;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (showGlyph) AppChannelGlyph(kind: channel.kind, size: 14),
        if (instance != null)
          AppStatusDot(color: instance, size: 8, ringColor: Colors.transparent),
        Flexible(
          child: Text(
            channel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.labelSm.copyWith(
              color: pill ? colors.textPrimary : colors.textSecondary,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: channel.title,
      child: ExcludeSemantics(
        child: pill
            ? Container(
                // A minimum, never a height: the label grows with text size.
                constraints: const BoxConstraints(minHeight: 24),
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: TajeerSpacing.sm,
                  vertical: TajeerSpacing.xs2,
                ),
                decoration: BoxDecoration(
                  color: instance == null
                      ? colors.surfaceMuted
                      : tintFor(instance, colors.surface),
                  borderRadius: TajeerRadii.fullAll,
                  border: Border.fromBorderSide(
                    BorderSide(
                      color:
                          instance?.withValues(alpha: 0.35) ??
                          colors.borderSubtle,
                    ),
                  ),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}
