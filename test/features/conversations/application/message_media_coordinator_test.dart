import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/message_media_coordinator.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

import '../../../support/fixed_clock.dart';
import '../domain/fakes/fake_message_repository.dart';
import 'fakes/fake_conversation_media_remote.dart';
import 'fakes/fake_file_storage.dart';

Message _message({
  String id = 'm1',
  String type = 'image',
  String? localMediaPath,
}) {
  return Message(
    id: id,
    conversationId: 'c1',
    direction: MessageDirection.inbound,
    state: MessageState.delivered,
    type: type,
    localMediaPath: localMediaPath,
    createdAt: testEpoch,
  );
}

void main() {
  late FakeMessageRepository messages;
  late FakeConversationMediaRemote remote;
  late FakeFileStorage storage;
  late MessageMediaCoordinator coordinator;

  setUp(() {
    messages = FakeMessageRepository();
    remote = FakeConversationMediaRemote();
    storage = FakeFileStorage();
    coordinator = MessageMediaCoordinator(
      messages: messages,
      remote: remote,
      storage: storage,
      logger: Logger('test', verbose: false),
    );
  });

  group('what is worth caching', () {
    test('a text message is left alone', () async {
      expect(await coordinator.ensureCached(_message(type: 'text')), isNull);
      expect(remote.downloadCalls, 0);
    });

    test('a sticker is cached, though it is not a sendable type', () async {
      // Stickers arrive from the customer and never leave the app, so they are
      // not in OutboundMedia.supportedTypes -- but the thread still has to
      // draw one offline.
      final String? path = await coordinator.ensureCached(
        _message(type: 'sticker'),
      );

      expect(path, endsWith('.jpg'));
      expect(remote.downloadCalls, 1);
    });

    test('each type lands under the extension its player expects', () async {
      Future<String?> cache(String type) =>
          coordinator.ensureCached(_message(id: 'm-$type', type: type));

      expect(await cache('image'), endsWith('.jpg'));
      expect(await cache('video'), endsWith('.mp4'));
      expect(await cache('audio'), endsWith('.m4a'));
      expect(await cache('document'), endsWith('.bin'));
    });
  });

  group('a file already on disk', () {
    test('is returned without asking the server again', () async {
      storage.present.add('/staged/already.jpg');

      final String? path = await coordinator.ensureCached(
        _message(localMediaPath: '/staged/already.jpg'),
      );

      expect(path, '/staged/already.jpg');
      expect(remote.downloadCalls, 0);
    });

    test('a cached video still gets its poster frame', () async {
      // The file survives a reinstall of the app; the thumbnail beside it may
      // not, and a video with no poster is a black rectangle in the thread.
      storage.present.add('/staged/clip.mp4');

      await coordinator.ensureCached(
        _message(type: 'video', localMediaPath: '/staged/clip.mp4'),
      );

      expect(storage.thumbnailed, <String>['/staged/clip.mp4']);
    });

    test('a path that has been reclaimed is downloaded again', () async {
      // The media cache is reclaimable storage: the row still names a file the
      // OS has since deleted.
      final String? path = await coordinator.ensureCached(
        _message(localMediaPath: '/staged/gone.jpg'),
      );

      expect(remote.downloadCalls, 1);
      expect(path, '/staged/m1.jpg');
    });
  });

  group('downloading', () {
    test('writes the bytes, records the path, and keeps the poster', () async {
      final String? path = await coordinator.ensureCached(
        _message(type: 'video'),
      );

      expect(path, '/staged/m1.mp4');
      expect(storage.written[path], remote.nextDownload);
      expect(storage.thumbnailed, <String>['/staged/m1.mp4']);
      expect(messages.mediaUpdates.single.localMediaPath, path);
    });

    test('an empty body is not a file', () async {
      remote.nextDownload = const <int>[];

      expect(await coordinator.ensureCached(_message()), isNull);
      expect(storage.written, isEmpty);
      expect(messages.mediaUpdates, isEmpty);
    });

    test('a JSON error page is not a file either', () async {
      // An expired media URL answers 200 with a JSON body. Written to disk it
      // becomes a permanently broken image the app never retries.
      remote.nextDownload = const <int>[0x7b, 0x22];

      expect(await coordinator.ensureCached(_message()), isNull);
      expect(storage.written, isEmpty);
    });

    test('a failure leaves the message as it was', () async {
      remote.failureToThrow = StateError('offline');

      expect(
        await coordinator.ensureCached(
          _message(localMediaPath: '/staged/gone.jpg'),
        ),
        '/staged/gone.jpg',
      );
      expect(messages.mediaUpdates, isEmpty);
    });

    test(
      'a second attempt while the first is running does not double up',
      () async {
        final Message message = _message();

        await Future.wait<String?>(<Future<String?>>[
          coordinator.ensureCached(message),
          coordinator.ensureCached(message),
        ]);

        expect(remote.downloadCalls, 1);
      },
    );

    test('and once it has finished, the file is there to be found', () async {
      final Message message = _message();

      await coordinator.ensureCached(message);
      await coordinator.ensureCached(message);

      // The second call finds the file on disk rather than the in-flight guard:
      // the guard must be released whatever happened.
      expect(remote.downloadCalls, 2);
    });
  });

  group('cacheAll', () {
    test('walks the thread, skipping what needs nothing', () async {
      await coordinator.cacheAll(<Message>[
        _message(id: 'a', type: 'text'),
        _message(id: 'b'),
        _message(id: 'c', type: 'audio'),
      ]);

      expect(remote.downloadCalls, 2);
      expect(storage.written.keys, <String>['/staged/b.jpg', '/staged/c.m4a']);
    });

    test('cacheOne is cacheAll for a single message', () async {
      await coordinator.cacheOne(_message());

      expect(remote.downloadCalls, 1);
    });
  });
}
