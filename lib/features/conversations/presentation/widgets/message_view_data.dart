import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../design_system/design_system.dart';
import '../../domain/entities/message.dart';

/// A message, as the thread draws it.
///
/// The one place a [Message] becomes an [AppMessageData]: which side, which
/// kind, and which delivery glyph. The domain's vocabulary stops here.
extension MessagePresentation on Message {
  AppMessageData toMessageData() => AppMessageData(
    id: id,
    side: isOutbound ? AppMessageSide.outgoing : AppMessageSide.incoming,
    sentAt: createdAt,
    kind: _kind,
    text: _present(body),
    // An incoming message has no delivery of ours to report.
    status: isOutbound ? state.toStatus() : AppMessageStatus.none,
    authorId: authorId,
    isFromBot: isFromBot,
    attachment: _attachment,
  );

  AppAttachmentData? get _attachment {
    if (mediaUrl == null && localMediaPath == null) return null;

    final String? path = localMediaPath;
    final File? file = path == null ? null : File(path);

    return AppAttachmentData(
      url: mediaUrl,
      localPath: localMediaPath,
      name: path == null ? null : p.basename(path),
      mimeType: path == null
          ? _mimeFromType(type)
          : _mimeFromPath(path) ?? _mimeFromType(type),
      sizeBytes: file != null && file.existsSync() ? file.lengthSync() : null,
    );
  }

  /// The provider's type vocabulary grows server-side, so an unknown type
  /// degrades — to text if there are words, to a file if there is media, and
  /// otherwise to "can't be shown" — rather than to an empty bubble.
  AppMessageKind get _kind => switch (type) {
    'text' =>
      _present(body) == null ? AppMessageKind.unsupported : AppMessageKind.text,
    'image' || 'sticker' => AppMessageKind.image,
    'video' => AppMessageKind.video,
    'audio' || 'voice' || 'ptt' => AppMessageKind.audio,
    'document' || 'file' => AppMessageKind.document,
    'location' => AppMessageKind.location,
    'system' => AppMessageKind.system,
    _ when _present(body) != null => AppMessageKind.text,
    _ when mediaUrl != null || localMediaPath != null =>
      AppMessageKind.document,
    _ => AppMessageKind.unsupported,
  };
}

/// The outbox's states, as delivery glyphs.
extension MessageStatePresentation on MessageState {
  AppMessageStatus toStatus() => switch (this) {
    MessageState.pending => AppMessageStatus.queued,
    MessageState.sending => AppMessageStatus.sending,
    MessageState.failed => AppMessageStatus.notSent,
    MessageState.sent => AppMessageStatus.sent,
    MessageState.delivered => AppMessageStatus.delivered,
    MessageState.read => AppMessageStatus.read,
    MessageState.discarded => AppMessageStatus.removed,
  };
}

String? _present(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : value;
}

String? _mimeFromType(String type) => switch (type) {
  'image' || 'sticker' => 'image/jpeg',
  'video' => 'video/mp4',
  'audio' || 'voice' || 'ptt' => 'audio/mp4',
  'document' || 'file' => 'application/octet-stream',
  _ => null,
};

String? _mimeFromPath(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.mp4' => 'video/mp4',
    '.mov' => 'video/quicktime',
    '.pdf' => 'application/pdf',
    '.mp3' => 'audio/mpeg',
    '.m4a' => 'audio/mp4',
    '.wav' => 'audio/wav',
    _ => null,
  };
}
