import '../../../../design_system/design_system.dart';
import '../../application/ports/attachment_picker.dart';

/// Maps a staged attachment onto what the composer draws.
///
/// The same boundary `message_view_data.dart` keeps for a `Message`: the
/// application layer answers in its own type, and the presentation layer is
/// where it becomes a design-system one. Nothing is decided here -- it is a
/// field-for-field copy -- and that is the point: the application layer did
/// not have to import the design system to produce it.
extension PickedAttachmentView on PickedAttachment {
  AppAttachmentData toAttachmentData() => AppAttachmentData(
    localPath: localPath,
    posterPath: posterPath,
    name: name,
    sizeBytes: sizeBytes,
    mimeType: mimeType,
  );
}
