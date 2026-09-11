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
    attachment: mediaUrl == null && localMediaPath == null
        ? null
        : AppAttachmentData(url: mediaUrl, localPath: localMediaPath),
  );

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
