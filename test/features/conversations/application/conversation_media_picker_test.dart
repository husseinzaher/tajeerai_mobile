import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/design_system/design_system.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/conversation_media_picker.dart';

import 'fakes/fake_file_storage.dart';

void main() {
  late FakeFileStorage storage;
  late Directory temp;

  setUp(() {
    storage = FakeFileStorage();
    temp = Directory.systemTemp.createTempSync('tajeer-picker-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  File onDisk(String name) {
    final File file = File('${temp.path}/$name')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);

    return file;
  }

  test('a cancelled pick is nothing, not an empty attachment', () async {
    expect(
      await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => null,
      ),
      isNull,
    );
    expect(storage.stagedFromPath, isEmpty);
  });

  group('staging', () {
    test('a file with a readable path is copied from it', () async {
      final File file = onDisk('photo.jpg');

      final AppAttachmentData? picked = await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: 'photo.jpg', file: file),
      );

      expect(storage.stagedFromPath, <String>[file.path]);
      expect(picked!.localPath, startsWith('/staged/'));
      expect(picked.localPath, endsWith('-photo.jpg'));
      expect(picked.name, 'photo.jpg');
      expect(picked.mimeType, 'image/jpeg');
      expect(picked.sizeBytes, 4);
    });

    test('a content URI with no path is streamed instead', () async {
      // An Android gallery video: `path` is null, and only the byte stream
      // reads it.
      final AppAttachmentData? picked = await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: 'clip.mp4', reportedLength: 9),
      );

      expect(storage.stagedFromPath, isEmpty);
      expect(storage.stagedFromStream, hasLength(1));
      expect(picked!.mimeType, 'video/mp4');
      expect(picked.sizeBytes, 9);
    });

    test('a path naming a file that is not there is streamed too', () async {
      await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(
          name: 'gone.jpg',
          reportedPath: '${temp.path}/gone.jpg',
        ),
      );

      expect(storage.stagedFromPath, isEmpty);
      expect(storage.stagedFromStream, hasLength(1));
    });

    test('when the stream fails it falls back to reading the bytes', () async {
      // Some content providers hand back a stream that throws on first read.
      // Losing the attachment there would be silent.
      storage.streamFailure = StateError('stream closed');

      final AppAttachmentData? picked = await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: 'clip.mp4'),
      );

      expect(storage.stagedFromBytes, hasLength(1));
      expect(picked, isNotNull);
    });
  });

  group('the video poster', () {
    test('is reported when the thumbnail is already beside the file', () async {
      storage.thumbnailsExist = true;

      final AppAttachmentData? picked = await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: 'clip.mp4'),
      );

      // The poster sits beside the staged file, under the same stem.
      final String staged = picked!.localPath!;

      expect(picked.posterPath, '${staged.replaceAll('.mp4', '')}_thumb.jpg');
    });

    test(
      'is left empty when the still frame has not been written yet',
      () async {
        final AppAttachmentData? picked = await ConversationMediaPicker.pick(
          storage: storage,
          pickFile: () async => _PickedFile(name: 'clip.mp4'),
        );

        expect(picked!.posterPath, isNull);
      },
    );

    test('is never asked for on something that is not a video', () async {
      final AppAttachmentData? picked = await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: 'photo.jpg', file: onDisk('a')),
      );

      expect(picked!.posterPath, isNull);
    });
  });

  group('naming and type', () {
    test('a name with a path in it keeps only its last segment', () async {
      // A document picker can return a display name that is a whole path;
      // used as a destination it would write outside the staging directory.
      await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: '../../etc/passwd.pdf'),
      );

      expect(storage.stagedFromStream.single, endsWith('-passwd.pdf'));
      expect(storage.stagedFromStream.single, isNot(contains('..')));
    });

    test('a nameless file still gets somewhere to be written', () async {
      await ConversationMediaPicker.pick(
        storage: storage,
        pickFile: () async => _PickedFile(name: '   '),
      );

      expect(storage.stagedFromStream.single, endsWith('-attachment'));
    });

    test(
      'the mime type is read from the extension the picker reports',
      () async {
        Future<String?> mimeOf(String name) async {
          final AppAttachmentData? picked = await ConversationMediaPicker.pick(
            storage: storage,
            pickFile: () async => _PickedFile(name: name),
          );

          return picked?.mimeType;
        }

        expect(await mimeOf('a.jpeg'), 'image/jpeg');
        expect(await mimeOf('a.PNG'), 'image/png');
        expect(await mimeOf('a.gif'), 'image/gif');
        expect(await mimeOf('a.webp'), 'image/webp');
        expect(await mimeOf('a.mov'), 'video/quicktime');
        expect(await mimeOf('a.m4v'), 'video/x-m4v');
        expect(await mimeOf('a.3gp'), 'video/3gpp');
        expect(await mimeOf('a.mkv'), 'video/x-matroska');
        expect(await mimeOf('a.webm'), 'video/webm');
        expect(await mimeOf('a.avi'), 'video/x-msvideo');
        expect(await mimeOf('a.pdf'), 'application/pdf');
        expect(await mimeOf('a.mp3'), 'audio/mpeg');
        expect(await mimeOf('a.m4a'), 'audio/mp4');
        expect(await mimeOf('a.wav'), 'audio/wav');
        expect(await mimeOf('a.zip'), 'application/octet-stream');
      },
    );

    test(
      'falls back to the name when the picker reports no extension',
      () async {
        final AppAttachmentData? picked = await ConversationMediaPicker.pick(
          storage: storage,
          pickFile: () async =>
              _PickedFile(name: 'invoice.pdf', reportedExtension: ''),
        );

        expect(picked!.mimeType, 'application/pdf');
      },
    );

    test('maps an attachment to the message type the backend knows', () {
      AppAttachmentData attachment(String mimeType) => AppAttachmentData(
        localPath: '/staged/a',
        name: 'a',
        mimeType: mimeType,
      );

      expect(
        ConversationMediaPicker.messageTypeFor(attachment('image/png')),
        'image',
      );
      expect(
        ConversationMediaPicker.messageTypeFor(attachment('video/mp4')),
        'video',
      );
      expect(
        ConversationMediaPicker.messageTypeFor(attachment('audio/mp4')),
        'audio',
      );
      expect(
        ConversationMediaPicker.messageTypeFor(attachment('application/pdf')),
        'document',
      );
    });
  });
}

/// A [PlatformFile] the picker can be handed without a gallery.
///
/// Extended rather than implemented: `PlatformFile` is a `base` class, so this
/// inherits its `extension` and `path` derivations and only supplies what a
/// real pick would carry.
final class _PickedFile extends PlatformFile {
  _PickedFile({
    required this.name,
    this.file,
    this.reportedPath,
    this.reportedLength,
    this.reportedExtension,
  });

  @override
  final String name;

  /// A real file on disk, for the path route.
  final File? file;

  /// A path that names nothing, for the route that has to notice.
  final String? reportedPath;

  final int? reportedLength;
  final String? reportedExtension;

  @override
  String? get extension => reportedExtension ?? super.extension;

  @override
  Uri get uri {
    final String? path = file?.path ?? reportedPath;

    return path == null ? Uri.parse('content://media/42') : Uri.file(path);
  }

  @override
  Never get xFile => throw UnimplementedError('not used by the picker');

  @override
  int? lengthSync() => file?.lengthSync() ?? reportedLength;

  @override
  Future<int?> length() async => lengthSync();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(<int>[1, 2]);

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream<Uint8List>.value(Uint8List.fromList(<int>[1, 2]));
}
