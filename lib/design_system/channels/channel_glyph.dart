import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import 'channel_descriptor.dart';

/// The mark for a kind of channel: its glyph, in its identity colour.
///
/// Line glyphs, not brand logos. The web marks channels with the same glyphs,
/// and a member who uses both should see one mark for one channel. Instagram,
/// Messenger and live chat share a glyph there and here; their colour and the
/// label that always sits somewhere beside them tell them apart.
///
/// [contained] sets it on its own soft wash with a cutout ring, for a place it
/// sits on top of something else — the corner of an avatar, where a bare glyph
/// has no contrast guarantee against a photograph.
class AppChannelGlyph extends StatelessWidget {
  const AppChannelGlyph({
    required this.kind,
    this.size = 16,
    this.contained = false,
    this.semanticLabel,
    super.key,
  });

  final AppChannelKind kind;
  final double size;
  final bool contained;

  /// Null when a label beside the glyph already names the channel, which is
  /// almost always: a screen reader should hear "WhatsApp" once, not twice.
  final String? semanticLabel;

  static IconData iconFor(AppChannelKind kind) => switch (kind) {
    AppChannelKind.whatsapp => LucideIcons.messageCircle,
    AppChannelKind.sms => LucideIcons.phone,
    AppChannelKind.email => LucideIcons.mail,
    AppChannelKind.instagram ||
    AppChannelKind.messenger ||
    AppChannelKind.liveChat => LucideIcons.messagesSquare,
  };

  /// The identity colour and its wash, from the channel tokens every preset
  /// shares.
  static (Color ink, Color wash) colorsFor(
    TajeerChannelColors channels,
    AppChannelKind kind,
  ) => switch (kind) {
    AppChannelKind.whatsapp => (channels.whatsapp, channels.whatsappSoft),
    AppChannelKind.sms => (channels.sms, channels.smsSoft),
    AppChannelKind.email => (channels.email, channels.emailSoft),
    AppChannelKind.instagram => (channels.instagram, channels.instagramSoft),
    AppChannelKind.messenger => (channels.messenger, channels.messengerSoft),
    AppChannelKind.liveChat => (channels.liveChat, channels.liveChatSoft),
  };

  @override
  Widget build(BuildContext context) {
    final (Color ink, Color wash) = colorsFor(context.channels, kind);
    final Widget glyph = Icon(iconFor(kind), size: size, color: ink);

    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: contained
          ? Container(
              width: size * 1.75,
              height: size * 1.75,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: wash,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: context.colors.surface, width: 2),
                ),
              ),
              child: glyph,
            )
          : glyph,
    );
  }
}
