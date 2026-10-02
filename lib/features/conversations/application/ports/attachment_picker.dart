/// Opens the device's file picker and hands back one attachment, staged.
///
/// An application port. Picking a file is a device capability -- the gallery,
/// the document provider, a content URI that has no path -- and staging it
/// into app-owned storage is what makes the attachment still readable when the
/// outbox sends it minutes later. Neither is the screen's business to know
/// about, and neither may the application layer name the plugin that does it.
/// `MediaPicker` in `infrastructure/adapters/conversations/device/` is the
/// implementation.
abstract interface class AttachmentPicker {
  /// The picked file, copied into app-owned storage; null when the member
  /// cancelled. Throws `FileSystemException` when the file could not be read.
  Future<PickedAttachment?> pick();
}

/// A file the member chose, already staged where the outbox can read it.
///
/// Plain data, in the application's vocabulary. The thread screen maps it onto
/// the design system's attachment type the way it maps a `Message` onto a
/// bubble -- the application layer never imports the design system.
final class PickedAttachment {
  const PickedAttachment({
    required this.localPath,
    required this.name,
    required this.mimeType,
    this.posterPath,
    this.sizeBytes,
  });

  /// Where the staged copy lives.
  final String localPath;

  /// A still frame beside a staged video, when one has been written.
  final String? posterPath;

  final String name;
  final String mimeType;
  final int? sizeBytes;

  @override
  bool operator ==(Object other) =>
      other is PickedAttachment &&
      other.localPath == localPath &&
      other.posterPath == posterPath &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode =>
      Object.hash(localPath, posterPath, name, mimeType, sizeBytes);
}
