import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Device file locations and basic file operations.
///
/// Exists so nothing else in the app calls `path_provider` directly: message
/// attachments need a *cached* location the OS may reclaim, while the database
/// needs a *permanent* one that survives a cache purge, and putting either in
/// the wrong place is a bug that only shows up under storage pressure.
class FileStorage {
  const FileStorage();

  /// Permanent application storage. Backed up, and never reclaimed by the OS.
  Future<Directory> documentsDirectory() => getApplicationDocumentsDirectory();

  /// Reclaimable storage for downloaded media.
  ///
  /// Anything here must be re-downloadable, because the OS may delete it at
  /// any time without telling the app.
  Future<Directory> cacheDirectory() async {
    final base = await getTemporaryDirectory();
    final media = Directory(p.join(base.path, 'media'));

    if (!media.existsSync()) {
      await media.create(recursive: true);
    }

    return media;
  }

  /// Absolute path a cached attachment would occupy, without creating it.
  Future<String> cachedMediaPath(String fileName) async {
    final directory = await cacheDirectory();

    return p.join(directory.path, fileName);
  }

  /// Synchronous by design: `avoid_slow_async_io` -- the async variants of
  /// these two are slower than the sync ones for a single stat call.
  bool exists(String path) => File(path).existsSync();

  int sizeOf(String path) => File(path).lengthSync();

  Future<void> delete(String path) async {
    final file = File(path);

    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Writes bytes to the media cache and returns the absolute path.
  Future<String> writeCachedMedia(String fileName, List<int> bytes) async {
    final path = await cachedMediaPath(fileName);
    await File(path).writeAsBytes(bytes, flush: true);

    return path;
  }

  /// Whether [path] already lives in the outbound staging directory.
  bool isStagedOutboundPath(String path) {
    return p.normalize(path).replaceAll(r'\', '/').contains('/outbound/');
  }

  /// Copies a picked attachment into permanent storage before it is queued.
  ///
  /// Gallery and document pickers often hand back a cache path or a URI-backed
  /// file the uploader cannot read reliably — especially for large videos.
  /// The outbox must send from a path the app owns.
  Future<String> stageOutboundMedia({
    required String sourcePath,
    required String destinationName,
  }) async {
    if (isStagedOutboundPath(sourcePath)) return sourcePath;

    final File source = File(sourcePath);

    if (!source.existsSync()) {
      throw FileSystemException(
        'The attachment could not be read.',
        sourcePath,
      );
    }

    final String destinationPath = await _outboundDestination(destinationName);

    await source.copy(destinationPath);

    if (_isVideoPath(destinationPath)) {
      await ensureVideoThumbnail(destinationPath);
    }

    return destinationPath;
  }

  /// Writes a picked attachment from memory into outbound storage.
  Future<String> stageOutboundMediaFromBytes({
    required List<int> bytes,
    required String destinationName,
  }) async {
    final String destinationPath = await _outboundDestination(destinationName);

    await File(destinationPath).writeAsBytes(bytes, flush: true);

    if (_isVideoPath(destinationPath)) {
      await ensureVideoThumbnail(destinationPath);
    }

    return destinationPath;
  }

  /// Streams a picked attachment into outbound storage.
  ///
  /// Used when the picker only exposes a content URI or byte stream, which is
  /// common for gallery videos on Android.
  Future<String> stageOutboundMediaFromStream({
    required Stream<List<int>> stream,
    required String destinationName,
  }) async {
    final String destinationPath = await _outboundDestination(destinationName);
    final IOSink sink = File(destinationPath).openWrite();

    await stream.forEach(sink.add);
    await sink.flush();
    await sink.close();

    if (_isVideoPath(destinationPath)) {
      await ensureVideoThumbnail(destinationPath);
    }

    return destinationPath;
  }

  static bool _isVideoPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.mp4' || '.mov' || '.m4v' || '.3gp' || '.webm' || '.mkv' => true,
      _ => false,
    };
  }

  /// The thumbnail path that sits beside a cached or staged video file.
  static String thumbnailPathFor(String videoPath) {
    return p.setExtension(
      p.join(
        p.dirname(videoPath),
        '${p.basenameWithoutExtension(videoPath)}_thumb',
      ),
      '.jpg',
    );
  }

  /// Writes a still frame next to [videoPath] when one is not already there.
  Future<String?> ensureVideoThumbnail(String videoPath) async {
    if (!exists(videoPath)) return null;

    final String thumbnailPath = thumbnailPathFor(videoPath);
    if (exists(thumbnailPath)) return thumbnailPath;

    final String? generated = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: thumbnailPath,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 320,
      quality: 75,
    );

    if (generated == null || !exists(generated)) return null;

    return generated;
  }

  Future<String> _outboundDestination(String destinationName) async {
    final Directory documents = await documentsDirectory();
    final Directory outbound = Directory(p.join(documents.path, 'outbound'));

    if (!outbound.existsSync()) {
      await outbound.create(recursive: true);
    }

    return p.join(outbound.path, destinationName);
  }
}
