import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
}
