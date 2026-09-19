import 'dart:async';
import 'dart:io';

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
    final String? localPath = attachment.localPath;

    Widget placeholder(IconData icon) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: colors.surfaceMuted,
      child: Icon(icon, size: 28, color: colors.textMuted),
    );

    final Widget picture = switch ((localPath, url)) {
      (final String path, _) when File(path).existsSync() => Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            placeholder(LucideIcons.imageOff),
      ),
      (_, final String networkUrl) => Image.network(
        networkUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? chunk,
        ) => chunk == null ? child : AppSkeleton(width: width, height: height),
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            placeholder(LucideIcons.imageOff),
      ),
      _ => placeholder(LucideIcons.image),
    };

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

/// Where one video is in its playback.
@immutable
class AppVideoPlayback {
  const AppVideoPlayback({
    this.playing = false,
    this.loading = false,
    this.initialized = false,
  });

  final bool playing;
  final bool loading;
  final bool initialized;
}

/// Plays videos inline, supplied by the app.
///
/// An interface and not an implementation: the design system draws the card
/// and must not grow a playback dependency to do it. The app holds the one real
/// player and hands it in; a test hands in a fake.
abstract interface class AppVideoController implements Listenable {
  AppVideoPlayback playbackOf(String messageId);

  /// The surface drawn inside the card while [messageId] is playing.
  Widget? surfaceFor(String messageId);

  Future<void> toggle({
    required String messageId,
    required AppAttachmentData attachment,
  });
}

/// A video a message carries: a play affordance and inline playback.
class AppVideoPreview extends StatelessWidget {
  const AppVideoPreview({
    required this.attachment,
    this.messageId,
    this.controller,
    this.width = 220,
    this.height = 160,
    super.key,
  });

  final AppAttachmentData attachment;
  final String? messageId;
  final AppVideoController? controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppVideoController? player = controller;
    if (player == null || messageId == null) {
      return _VideoFrame(attachment: attachment, width: width, height: height);
    }

    return ListenableBuilder(
      listenable: player,
      builder: (BuildContext context, Widget? child) => _VideoFrame(
        attachment: attachment,
        messageId: messageId!,
        controller: player,
        width: width,
        height: height,
      ),
    );
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({
    required this.attachment,
    required this.width,
    required this.height,
    this.messageId,
    this.controller,
  });

  final AppAttachmentData attachment;
  final String? messageId;
  final AppVideoController? controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final String label = attachment.name ?? strings.video;
    final AppVideoController? player = controller;
    final String? id = messageId;
    final AppVideoPlayback playback = player == null || id == null
        ? const AppVideoPlayback()
        : player.playbackOf(id);
    final Widget? surface = player == null || id == null
        ? null
        : player.surfaceFor(id);
    final bool showControls =
        !playback.initialized || !playback.playing || playback.loading;
    final String? posterPath = attachment.posterPath;
    final bool hasPoster = posterPath != null && File(posterPath).existsSync();
    final bool showSurface = playback.initialized && surface != null;

    Future<void> toggle() async {
      if (player == null || id == null) return;

      await player.toggle(messageId: id, attachment: attachment);
    }

    return Semantics(
      container: true,
      button: player != null,
      label: label,
      onTap: player == null ? null : toggle,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: player == null ? null : () => unawaited(toggle()),
          borderRadius: TajeerRadii.mdAll,
          scaleOnPress: false,
          child: ClipRRect(
            borderRadius: TajeerRadii.mdAll,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[
                  if (showSurface)
                    FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: surface,
                    )
                  else if (hasPoster)
                    Image.file(
                      File(posterPath),
                      fit: BoxFit.cover,
                      width: width,
                      height: height,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) => ColoredBox(color: colors.surfaceMuted),
                    )
                  else
                    ColoredBox(color: colors.surfaceMuted),
                  if (playback.loading)
                    Center(
                      child: SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.textInverse,
                        ),
                      ),
                    ),
                  if (showControls && !playback.loading)
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceOverlay,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        playback.playing ? LucideIcons.pause : LucideIcons.play,
                        size: 22,
                        color: colors.textInverse,
                      ),
                    ),
                  PositionedDirectional(
                    start: TajeerSpacing.sm,
                    end: TajeerSpacing.sm,
                    bottom: TajeerSpacing.sm,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceOverlay.withValues(alpha: 0.72),
                        borderRadius: TajeerRadii.smAll,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TajeerSpacing.xs,
                          vertical: TajeerSpacing.xs2,
                        ),
                        child: Row(
                          spacing: TajeerSpacing.xs2,
                          children: <Widget>[
                            Icon(
                              LucideIcons.video,
                              size: 14,
                              color: colors.textInverse,
                            ),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.type.caption.copyWith(
                                  color: colors.textInverse,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                      // A file name and a size are identifiers, read left to right in
                      // either language the way a phone number is: laid out in
                      // Arabic, "471 KB" reads "KB 471".
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: context.type.labelMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (size != null)
                        Text(
                          size,
                          textDirection: TextDirection.ltr,
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
    final String? mimeType = attachment.mimeType;
    final bool picture = mimeType?.startsWith('image/') ?? false;
    final bool video = mimeType?.startsWith('video/') ?? false;

    if (video) {
      return SizedBox.square(
        dimension: thumbnail,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AppVideoPreview(
                attachment: attachment,
                width: thumbnail,
                height: thumbnail,
              ),
            ),
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
