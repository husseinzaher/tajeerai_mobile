import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../features/conversations/application/ports/attachment_picker.dart';
import '../../../storage/file_storage.dart';

/// Opens a file picker and answers with one picked file, or nothing.
typedef PickOneFile = Future<PlatformFile?> Function();

/// The system file picker, staging what it returns into app-owned storage.
///
/// The conversations feature's implementation of [AttachmentPicker]. Gallery
/// videos on Android often come back as content URIs with no local
/// [PlatformFile.path]; staging here -- via path, stream, or bytes -- keeps the
/// attachment readable when the member sends it, which may be minutes later
/// and from the outbox rather than from this screen.
final class MediaPicker implements AttachmentPicker {
  /// [pickFile] is the system picker, and is a parameter only so that the
  /// three staging routes can be exercised without a gallery.
  const MediaPicker({
    required FileStorage storage,
    PickOneFile pickFile = _systemPicker,
  }) : _storage = storage,
       _pickFile = pickFile;

  final FileStorage _storage;
  final PickOneFile _pickFile;

  @override
  Future<PickedAttachment?> pick() async {
    final PlatformFile? file = await _pickFile();

    if (file == null) return null;

    final String mimeType = _mimeFromFile(file);
    final String destinationName =
        '${DateTime.now().millisecondsSinceEpoch}-${_safeFileName(file.name)}';

    final String stagedPath = await _stagePickedFile(
      file: file,
      destinationName: destinationName,
    );

    final int? bytes = file.lengthSync() ?? await file.length();

    return PickedAttachment(
      localPath: stagedPath,
      posterPath: mimeType.startsWith('video/')
          ? _posterPathFor(stagedPath)
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

  Future<String> _stagePickedFile({
    required PlatformFile file,
    required String destinationName,
  }) async {
    final String? path = file.path;

    if (path != null && File(path).existsSync()) {
      return _storage.stageOutboundMedia(
        sourcePath: path,
        destinationName: destinationName,
      );
    }

    try {
      return await _storage.stageOutboundMediaFromStream(
        stream: file.readAsByteStream(),
        destinationName: destinationName,
      );
    } on Object {
      final Uint8List bytes = await file.readAsBytes();

      return _storage.stageOutboundMediaFromBytes(
        bytes: bytes,
        destinationName: destinationName,
      );
    }
  }

  String? _posterPathFor(String videoPath) {
    final String thumbnailPath = FileStorage.thumbnailPathFor(videoPath);

    return _storage.exists(thumbnailPath) ? thumbnailPath : null;
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
}
