import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/value_objects/outbound_media.dart';

/// Opens the system file picker and returns an attachment the composer can show.
abstract final class ConversationMediaPicker {
  static Future<AppAttachmentData?> pick() async {
    final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);

    if (file == null) return null;

    final String? path = file.path;

    if (path == null || path.isEmpty) return null;

    final String mimeType = file.extension != null && file.extension!.isNotEmpty
        ? _mimeFromExtension(file.extension!)
        : 'application/octet-stream';

    final int bytes = File(path).existsSync() ? File(path).lengthSync() : 0;

    return AppAttachmentData(
      localPath: path,
      name: file.name,
      sizeBytes: bytes,
      mimeType: mimeType,
    );
  }

  static String _mimeFromExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'pdf' => 'application/pdf',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
  }

  /// Maps a composer attachment to the backend message type.
  static String messageTypeFor(AppAttachmentData attachment) =>
      messageTypeFromMime(attachment.mimeType);
}
