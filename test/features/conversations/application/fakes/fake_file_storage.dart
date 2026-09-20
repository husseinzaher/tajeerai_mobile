import 'package:TajeerAi/infrastructure/storage/file_storage.dart';

/// [FileStorage] with the disk taken out.
///
/// Subclassed rather than reimplemented: the coordinators under test call a
/// handful of its methods, and overriding those keeps this honest about the
/// rest — a method nobody stubbed still runs the real one and fails loudly
/// rather than quietly answering nothing.
class FakeFileStorage extends FileStorage {
  FakeFileStorage();

  /// Paths [exists] answers true for.
  final Set<String> present = <String>{};

  /// Every path written, in order, and what was written to it.
  final Map<String, List<int>> written = <String, List<int>>{};

  /// Video paths a thumbnail was asked for.
  final List<String> thumbnailed = <String>[];

  /// Staging calls, by the route they took in.
  final List<String> stagedFromPath = <String>[];
  final List<String> stagedFromStream = <String>[];
  final List<String> stagedFromBytes = <String>[];

  /// When set, streaming fails and the picker must fall back to bytes.
  Object? streamFailure;

  /// Answers [exists] for any `…_thumb.jpg`, which is how a staged video's
  /// poster frame is found without knowing the timestamped name it was
  /// staged under.
  bool thumbnailsExist = false;

  String directory = '/staged';

  @override
  bool exists(String path) {
    if (thumbnailsExist && path.endsWith('_thumb.jpg')) return true;

    return present.contains(path);
  }

  @override
  Future<String> writeCachedMedia(String fileName, List<int> bytes) async {
    final String path = '$directory/$fileName';

    written[path] = bytes;
    present.add(path);

    return path;
  }

  @override
  Future<String?> ensureVideoThumbnail(String videoPath) async {
    thumbnailed.add(videoPath);

    return null;
  }

  @override
  Future<String> stageOutboundMedia({
    required String sourcePath,
    required String destinationName,
  }) async {
    stagedFromPath.add(sourcePath);

    return '$directory/$destinationName';
  }

  @override
  Future<String> stageOutboundMediaFromStream({
    required Stream<List<int>> stream,
    required String destinationName,
  }) async {
    final Object? failure = streamFailure;

    if (failure != null) throw failure;

    stagedFromStream.add(destinationName);

    return '$directory/$destinationName';
  }

  @override
  Future<String> stageOutboundMediaFromBytes({
    required List<int> bytes,
    required String destinationName,
  }) async {
    stagedFromBytes.add(destinationName);

    return '$directory/$destinationName';
  }
}
