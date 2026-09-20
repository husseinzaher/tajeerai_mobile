import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:TajeerAi/infrastructure/storage/file_storage.dart';

void main() {
  late Directory documents;

  setUp(() async {
    PathProviderPlatform.instance = _TempPathProvider(
      onDocuments: (Directory directory) => documents = directory,
    );
  });

  test('stageOutboundMediaFromStream writes readable outbound files', () async {
    const FileStorage storage = FileStorage();

    final String path = await storage.stageOutboundMediaFromStream(
      stream: Stream<List<int>>.fromIterable(<List<int>>[
        <int>[1, 2, 3],
        <int>[4, 5],
      ]),
      destinationName: 'clip.mp4',
    );

    expect(storage.isStagedOutboundPath(path), isTrue);
    expect(File(path).readAsBytesSync(), <int>[1, 2, 3, 4, 5]);
  });

  test('stageOutboundMedia skips already staged paths', () async {
    const FileStorage storage = FileStorage();
    final File existing = File('${documents.path}/outbound/already.mp4');
    await existing.parent.create(recursive: true);
    await existing.writeAsBytes(<int>[9]);

    final String path = await storage.stageOutboundMedia(
      sourcePath: existing.path,
      destinationName: 'ignored.mp4',
    );

    expect(path, existing.path);
    expect(File(path).readAsBytesSync(), <int>[9]);
  });
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider({required this.onDocuments});

  final void Function(Directory directory) onDocuments;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final Directory directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}tajeer-docs-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    onDocuments(directory);

    return directory.path;
  }
}
