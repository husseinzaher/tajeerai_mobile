import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../feedback/progress_bar.dart';
import '../loaders/skeleton.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/bidi_text.dart';
import '../primitives/pressable.dart';
import 'message_data.dart';

/// A file's size in the reader's terms: "820 KB", "2.4 MB". Latin digits in
/// both languages, like every figure in the product.
abstract final class AppFileSize {
  static String format(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    const List<String> units = <String>['KB', 'MB', 'GB'];
    double value = bytes / 1024;
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final String figure = value >= 10
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$figure ${units[unit]}';
  }
}

/// A thumbnail of a picture a message carries.
///
/// It draws the picture and reports a tap. It does not own a gallery, a route
/// or a zoom gesture — opening a picture is the app's to decide, and a design
/// system that pushed its own route would be a design system that knows the
/// router.
class AppImagePreview extends StatelessWidget {
  const AppImagePreview({
    required this.attachment,
    this.onOpen,
    this.width = 220,
    this.height = 160,
    super.key,
  });

  final AppAttachmentData attachment;
  final VoidCallback? onOpen;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final String? url = attachment.url;

    Widget placeholder(IconData icon) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: colors.surfaceMuted,
      child: Icon(icon, size: 28, color: colors.textMuted),
    );

    final Widget picture = url == null
        // Still on this device: nothing to fetch yet.
        ? placeholder(LucideIcons.image)
        : Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            loadingBuilder:
                (BuildContext context, Widget child, ImageChunkEvent? chunk) =>
                    chunk == null
                    ? child
                    : AppSkeleton(width: width, height: height),
            // A broken picture must not blank the bubble it sits in.
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stack,
            ) => placeholder(LucideIcons.imageOff),
          );

    return Semantics(
      container: true,
      image: true,
      button: onOpen != null,
      label: attachment.name ?? context.strings.photo,
      onTap: onOpen,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onOpen,
          borderRadius: TajeerRadii.mdAll,
          scaleOnPress: false,
          child: ClipRRect(borderRadius: TajeerRadii.mdAll, child: picture),
        ),
      ),
    );
  }
}

/// A file a message carries: its name, its size, and a tap to open it.
class AppFilePreview extends StatelessWidget {
  const AppFilePreview({
    required this.attachment,
    this.onOpen,
    this.onRemove,
    super.key,
  });

  final AppAttachmentData attachment;
  final VoidCallback? onOpen;

  /// Offered by the composer, for a file that has not been sent yet.
  final VoidCallback? onRemove;

  static IconData _iconFor(String? mimeType) => switch (mimeType) {
    final String type when type.startsWith('image/') => LucideIcons.image,
    final String type when type.startsWith('audio/') => LucideIcons.mic,
    final String type when type.startsWith('video/') => LucideIcons.video,
    _ => LucideIcons.fileText,
  };

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final String name = attachment.name ?? strings.document;
    final int? bytes = attachment.sizeBytes;
    final String? size = bytes == null ? null : AppFileSize.format(bytes);

    final Widget card = Semantics(
      container: true,
      button: onOpen != null,
      label: <String?>[name, size].whereType<String>().join(', '),
      onTap: onOpen,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onOpen,
          borderRadius: TajeerRadii.mdAll,
          scaleOnPress: false,
          child: Padding(
            padding: const EdgeInsets.all(TajeerSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: TajeerRadii.mdAll,
                  ),
                  child: Icon(
                    _iconFor(attachment.mimeType),
                    size: 20,
                    color: colors.textSecondary,
                  ),
                ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppBidiText(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.labelMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (size != null)
                        Text(
                          size,
                          style: context.type.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onRemove == null) {
      return card;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: card),
        AppButton.icon(
          icon: const Icon(LucideIcons.x),
          semanticLabel: strings.remove,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// Where one voice note is in its playback.
@immutable
class AppAudioPlayback {
  const AppAudioPlayback({
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
  });

  final bool playing;
  final Duration position;
  final Duration? duration;

  /// How far through, from 0 to 1. Null until the length is known.
  double? get progress {
    final int? total = duration?.inMilliseconds;
    if (total == null || total <= 0) {
      return null;
    }
    return (position.inMilliseconds / total).clamp(0, 1).toDouble();
  }

  /// `m:ss`, in Latin digits.
  static String clock(Duration at) =>
      '${at.inMinutes}:${(at.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is AppAudioPlayback &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(playing, position, duration);
}

/// Plays voice notes, supplied by the app.
///
/// An interface and not an implementation: the design system draws a player
/// and must not grow a playback dependency to do it. The app holds the one real
/// player and hands it in; a test hands in a fake. Without one, a voice note is
/// drawn but cannot be played.
abstract interface class AppAudioController implements Listenable {
  AppAudioPlayback playbackOf(AppAttachmentData attachment);

  Future<void> toggle(AppAttachmentData attachment);
}

/// A voice note: play, how far through, and how long.
class AppAudioMessage extends StatelessWidget {
  const AppAudioMessage({
    required this.attachment,
    this.controller,
    this.duration,
    super.key,
  });

  final AppAttachmentData attachment;
  final AppAudioController? controller;

  /// The length, when it is known before anything plays.
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final AppAudioController? player = controller;
    if (player == null) {
      return _Player(playback: AppAudioPlayback(duration: duration));
    }
    return ListenableBuilder(
      listenable: player,
      builder: (BuildContext context, Widget? child) => _Player(
        playback: player.playbackOf(attachment),
        onToggle: () => unawaited(player.toggle(attachment)),
      ),
    );
  }
}

class _Player extends StatelessWidget {
  const _Player({required this.playback, this.onToggle});

  final AppAudioPlayback playback;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final Duration? length = playback.duration;
    final String time = AppAudioPlayback.clock(
      playback.playing || length == null ? playback.position : length,
    );

    return SizedBox(
      width: 220,
      child: Row(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppButton.icon(
            icon: Icon(playback.playing ? LucideIcons.pause : LucideIcons.play),
            semanticLabel: playback.playing ? strings.pause : strings.play,
            variant: AppButtonVariant.soft,
            shape: AppButtonShape.circle,
            onPressed: onToggle,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
                AppProgressBar(
                  value: playback.progress ?? 0,
                  semanticLabel: strings.voiceMessage,
                ),
                Text(
                  time,
                  style: context.type.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A link a message carries: where it goes, and what it says it is.
class AppLinkPreview extends StatelessWidget {
  const AppLinkPreview({
    required this.url,
    this.title,
    this.description,
    this.onOpen,
    super.key,
  });

  final Uri url;
  final String? title;
  final String? description;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Semantics(
      container: true,
      link: true,
      label: <String?>[title, url.host].whereType<String>().join(', '),
      onTap: onOpen,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onOpen,
          borderRadius: TajeerRadii.mdAll,
          scaleOnPress: false,
          child: Container(
            padding: const EdgeInsets.all(TajeerSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: TajeerRadii.mdAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TajeerSpacing.xs2,
                  children: <Widget>[
                    Icon(LucideIcons.globe, size: 12, color: colors.textMuted),
                    Flexible(
                      child: Text(
                        url.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (title != null)
                  AppBidiText(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.labelMd.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (description != null)
                  AppBidiText(
                    description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A file waiting in the composer, with a way to take it out again.
class AppAttachmentPreview extends StatelessWidget {
  const AppAttachmentPreview({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final AppAttachmentData attachment;
  final VoidCallback onRemove;

  static const double thumbnail = 72;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final bool picture = attachment.mimeType?.startsWith('image/') ?? false;

    if (!picture) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.elevation.card.tone,
          borderRadius: TajeerRadii.mdAll,
          border: Border.fromBorderSide(
            BorderSide(color: context.elevation.card.hairline),
          ),
        ),
        child: AppFilePreview(attachment: attachment, onRemove: onRemove),
      );
    }

    return SizedBox.square(
      dimension: thumbnail,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AppImagePreview(
              attachment: attachment,
              width: thumbnail,
              height: thumbnail,
            ),
          ),
          // Inside the thumbnail, not hanging off its corner: a child outside
          // its parent's bounds cannot be hit.
          PositionedDirectional(
            top: TajeerSpacing.xs2,
            end: TajeerSpacing.xs2,
            child: Semantics(
              button: true,
              label: strings.remove,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceOverlay,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: colors.textInverse,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
