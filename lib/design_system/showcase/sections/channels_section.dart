import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../channels/channel_badge.dart';
import '../../channels/channel_capabilities.dart';
import '../../channels/channel_descriptor.dart';
import '../../channels/channel_glyph.dart';
import '../../channels/channel_palette.dart';
import '../../display/avatar.dart';
import '../showcase_fixtures.dart';
import '../showcase_section.dart';

const Map<AppChannelKind, String> _labels = <AppChannelKind, String>{
  AppChannelKind.whatsapp: ShowcaseFixtures.whatsapp,
  AppChannelKind.sms: ShowcaseFixtures.sms,
  AppChannelKind.email: ShowcaseFixtures.email,
  AppChannelKind.instagram: 'إنستغرام',
  AppChannelKind.messenger: 'ماسنجر',
  AppChannelKind.liveChat: 'الدردشة المباشرة',
};

/// The backend's capability table as it stands. Fixtures, for the showcase
/// alone: in the app a channel's capabilities arrive with the channel.
const Map<AppChannelKind, AppChannelCapabilities> _capabilities =
    <AppChannelKind, AppChannelCapabilities>{
      AppChannelKind.whatsapp: AppChannelCapabilities(
        text: true,
        images: true,
        video: true,
        audio: true,
        documents: true,
        templates: true,
        buttons: true,
        lists: true,
        reactions: true,
        readReceipts: true,
        location: true,
        replies: true,
      ),
      AppChannelKind.sms: AppChannelCapabilities.textOnly,
      AppChannelKind.email: AppChannelCapabilities(
        text: true,
        images: true,
        documents: true,
      ),
      AppChannelKind.instagram: AppChannelCapabilities(
        text: true,
        images: true,
        video: true,
        reactions: true,
        replies: true,
      ),
      AppChannelKind.messenger: AppChannelCapabilities(
        text: true,
        images: true,
        video: true,
        audio: true,
        documents: true,
        buttons: true,
        reactions: true,
        readReceipts: true,
        typingIndicator: true,
        replies: true,
      ),
      AppChannelKind.liveChat: AppChannelCapabilities(
        text: true,
        images: true,
        documents: true,
        buttons: true,
        readReceipts: true,
        typingIndicator: true,
        replies: true,
      ),
    };

// Channel ids chosen for where the shared hash puts them: blue, mauve, fuchsia.
const String _salesId = '22222222-2222-4222-8222-222222222222';
const String _supportId = '55555555-5555-4555-8555-555555555555';
const String _riyadhId = 'قناة-المبيعات';

AppChannelDescriptor _channel(
  AppChannelKind kind, {
  String? name,
  String? id,
}) => AppChannelDescriptor(
  kind: kind,
  label: _labels[kind]!,
  name: name,
  color: id == null ? null : AppChannelPalette.autoColorFor(id),
  capabilities: _capabilities[kind]!,
);

ShowcaseSection channelsSection() => ShowcaseSection(
  title: 'Channels',
  icon: LucideIcons.messageCircle,
  description:
      'Three facts about a channel, kept apart: which kind it is, which one of '
      'several it is, and what it can carry.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Kinds',
      description:
          'Line glyphs in the named identity colours every preset shares, bare '
          'and on their own wash. Instagram, Messenger and live chat share a '
          'glyph, as they do on the web; colour and label tell them apart.',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.lg,
        runSpacing: TajeerSpacing.md,
        children: <Widget>[
          for (final AppChannelKind kind in AppChannelKind.values)
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                AppChannelGlyph(kind: kind, size: 20),
                AppChannelGlyph(kind: kind, size: 14, contained: true),
                Text(
                  _labels[kind]!,
                  style: context.type.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Which one of several',
      description:
          'The ten instance colours, in the backend\'s order. A channel nobody '
          'coloured lands on one by a hash of its id — the server\'s own hash, '
          'so it is the same colour on the web.',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.sm,
        runSpacing: TajeerSpacing.sm,
        children: <Widget>[
          for (int slot = 0; slot < AppChannelPalette.colors.length; slot++)
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppChannelPalette.colors[slot],
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  '$slot',
                  style: context.type.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Badge',
      description:
          'The channel on one line. The text stays ink: the colour travels in '
          'the dot and, in the pill, in the tint behind the text.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppChannelBadge(
            channel: _channel(
              AppChannelKind.whatsapp,
              name: 'المبيعات',
              id: _salesId,
            ),
          ),
          AppChannelBadge(
            channel: _channel(
              AppChannelKind.email,
              name: 'الدعم',
              id: _supportId,
            ),
          ),
          AppChannelBadge(channel: _channel(AppChannelKind.sms)),
          AppChannelBadge(
            channel: _channel(
              AppChannelKind.whatsapp,
              name: 'المبيعات',
              id: _salesId,
            ),
            emphasis: AppChannelBadgeEmphasis.pill,
          ),
          AppChannelBadge(
            channel: _channel(
              AppChannelKind.instagram,
              name: 'سيرفر السعودية',
              id: _riyadhId,
            ),
            emphasis: AppChannelBadgeEmphasis.pill,
          ),
          AppChannelBadge(
            channel: _channel(AppChannelKind.liveChat),
            emphasis: AppChannelBadgeEmphasis.pill,
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'On an avatar',
      description:
          'Contained on its wash with a cutout ring, in the corner the avatar '
          'keeps for it.',
      builder: (BuildContext context) => const Row(
        spacing: TajeerSpacing.md,
        children: <Widget>[
          AppAvatar(
            name: ShowcaseFixtures.customer,
            size: 48,
            badge: AppChannelGlyph(
              kind: AppChannelKind.whatsapp,
              size: 12,
              contained: true,
            ),
          ),
          AppAvatar(
            name: ShowcaseFixtures.secondCustomer,
            size: 48,
            badge: AppChannelGlyph(
              kind: AppChannelKind.instagram,
              size: 12,
              contained: true,
            ),
          ),
          AppAvatar(
            name: ShowcaseFixtures.latinCustomer,
            size: 48,
            badge: AppChannelGlyph(
              kind: AppChannelKind.email,
              size: 12,
              contained: true,
            ),
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Capabilities, not channels',
      description:
          'What a composer would offer on each. Nothing asks which channel it '
          'is: the paperclip follows canAttach, the microphone audio, the quote '
          'replies. SMS ends up with text alone, and no code says "if SMS".',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          for (final AppChannelKind kind in AppChannelKind.values)
            Row(
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                Expanded(child: AppChannelBadge(channel: _channel(kind))),
                for (final (bool offered, IconData icon) in <(bool, IconData)>[
                  (_capabilities[kind]!.canAttach, LucideIcons.paperclip),
                  (_capabilities[kind]!.audio, LucideIcons.mic),
                  (_capabilities[kind]!.replies, LucideIcons.reply),
                  (_capabilities[kind]!.templates, LucideIcons.fileText),
                ])
                  if (offered)
                    Icon(icon, size: 18, color: context.colors.textSecondary),
              ],
            ),
        ],
      ),
    ),
  ],
);
