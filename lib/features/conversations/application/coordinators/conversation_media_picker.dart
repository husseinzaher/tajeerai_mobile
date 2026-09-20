import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../design_system/design_system.dart';
import '../../../../infrastructure/storage/file_storage.dart';
import '../../domain/value_objects/outbound_media.dart';

/// Opens a file picker and answers with one picked file, or nothing.
typedef PickOneFile = Future<PlatformFile?> Function();

/// Opens the system file picker and returns an attachment the composer can show.
abstract final class ConversationMediaPicker {
  /// Picks a file and copies it into app-owned storage before returning.
  ///
  /// Gallery videos on Android often come back as content URIs with no local
  /// [PlatformFile.path]. Staging here — via path, stream, or bytes — keeps
  /// the attachment readable when the member sends it.
  ///
  /// [pickFile] is the system picker, and is a parameter only so that the
  /// three staging routes can be exercised without a gallery.
  static Future<AppAttachmentData?> pick({
    required FileStorage storage,
    PickOneFile pickFile = _systemPicker,
  }) async {
    final PlatformFile? file = await pickFile();

    if (file == null) return null;

    final String mimeType = _mimeFromFile(file);
    final String destinationName =
        '${DateTime.now().millisecondsSinceEpoch}-${_safeFileName(file.name)}';

    final String stagedPath = await _stagePickedFile(
      storage: storage,
      file: file,
      destinationName: destinationName,
    );

    final int? bytes = file.lengthSync() ?? await file.length();

    return AppAttachmentData(
      localPath: stagedPath,
      posterPath: mimeType.startsWith('video/')
          ? _posterPathFor(storage, stagedPath)
          : null,
      name: file.name,
      sizeBytes: bytes,
      mimeType: mimeType,
    );
  }

  static Future<PlatformFile?> _systemPicker() => FilePicker.pickFile(
    type: FileType.any,
    compressionQuality: 0,
    darwinOptions: const DarwinOptions(
      assetRepresentationMode: DarwinAssetRepresentationMode.current,
    ),
  );

  static Future<String> _stagePickedFile({
    required FileStorage storage,
    required PlatformFile file,
    required String destinationName,
  }) async {
    final String? path = file.path;

    if (path != null && File(path).existsSync()) {
      return storage.stageOutboundMedia(
        sourcePath: path,
        destinationName: destinationName,
      );
    }

    try {
      return await storage.stageOutboundMediaFromStream(
        stream: file.readAsByteStream(),
        destinationName: destinationName,
      );
    } on Object {
      final Uint8List bytes = await file.readAsBytes();

      return storage.stageOutboundMediaFromBytes(
        bytes: bytes,
        destinationName: destinationName,
      );
    }
  }

  static String? _posterPathFor(FileStorage storage, String videoPath) {
    final String thumbnailPath = FileStorage.thumbnailPathFor(videoPath);

    return storage.exists(thumbnailPath) ? thumbnailPath : null;
  }

  static String _safeFileName(String name) {
    final String trimmed = name.trim();

    return trimmed.isEmpty ? 'attachment' : p.basename(trimmed);
  }

  static String _mimeFromFile(PlatformFile file) {
    final String? extension = file.extension;

    if (extension != null && extension.isNotEmpty) {
      return _mimeFromExtension(extension);
    }

    return _mimeFromExtension(p.extension(file.name).replaceFirst('.', ''));
  }

  static String _mimeFromExtension(String extension) {
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4v' => 'video/x-m4v',
      '3gp' || '3gpp' => 'video/3gpp',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
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
