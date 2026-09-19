import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tajeerai_mobile/design_system/messaging/message_data.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/widgets/message_view_data.dart';
import 'package:tajeerai_mobile/infrastructure/storage/file_storage.dart';

import '../../../support/fixed_clock.dart';

Message _message({
  MessageDirection direction = MessageDirection.outbound,
  MessageState state = MessageState.sent,
  String type = 'text',
  String? body = 'Hello',
  String? mediaUrl,
  String? localMediaPath,
  bool isFromBot = false,
}) => Message(
  id: 'm1',
  conversationId: 'c1',
  direction: direction,
  state: state,
  createdAt: testEpoch,
  type: type,
  body: body,
  mediaUrl: mediaUrl,
  localMediaPath: localMediaPath,
  authorId: 'u1',
  isFromBot: isFromBot,
);

void main() {
  test('every outbox state has its glyph', () {
    // Walks MessageState.values, so a state added to the domain fails here
    // before it draws as the wrong thing.
    const Map<MessageState, AppMessageStatus> expected =
        <MessageState, AppMessageStatus>{
          MessageState.pending: AppMessageStatus.queued,
          MessageState.sending: AppMessageStatus.sending,
          MessageState.failed: AppMessageStatus.notSent,
          MessageState.sent: AppMessageStatus.sent,
          MessageState.delivered: AppMessageStatus.delivered,
          MessageState.read: AppMessageStatus.read,
          MessageState.discarded: AppMessageStatus.removed,
        };

    for (final MessageState state in MessageState.values) {
      expect(
        _message(state: state).toMessageData().status,
        expected[state],
        reason: state.name,
      );
    }
  });

  test('outgoing is ours; incoming has no delivery of ours to report', () {
    final AppMessageData ours = _message().toMessageData();
    final AppMessageData theirs = _message(
      direction: MessageDirection.inbound,
      state: MessageState.read,
    ).toMessageData();

    expect(ours.side, AppMessageSide.outgoing);
    expect(theirs.side, AppMessageSide.incoming);
    expect(theirs.status, AppMessageStatus.none);
  });

  test('the provider\'s types map onto the kinds the thread can draw', () {
    AppMessageKind kindOf(
      String type, {
      String? body = 'caption',
      String? mediaUrl,
    }) => _message(
      type: type,
      body: body,
      mediaUrl: mediaUrl,
    ).toMessageData().kind;

    expect(kindOf('text'), AppMessageKind.text);
    expect(kindOf('image'), AppMessageKind.image);
    expect(kindOf('sticker'), AppMessageKind.image);
    expect(kindOf('video'), AppMessageKind.video);
    for (final String audio in <String>['audio', 'voice', 'ptt']) {
      expect(kindOf(audio), AppMessageKind.audio, reason: audio);
    }
    expect(kindOf('document'), AppMessageKind.document);
    expect(kindOf('file'), AppMessageKind.document);
    expect(kindOf('location'), AppMessageKind.location);
    expect(kindOf('system'), AppMessageKind.system);
  });

  test('a type this build does not know degrades instead of vanishing', () {
    AppMessageKind kindOf({String? body, String? mediaUrl}) => _message(
      type: 'poll',
      body: body,
      mediaUrl: mediaUrl,
    ).toMessageData().kind;

    expect(kindOf(body: 'Which colour?'), AppMessageKind.text);
    expect(
      kindOf(mediaUrl: 'https://cdn.test/file.bin'),
      AppMessageKind.document,
    );
    expect(kindOf(), AppMessageKind.unsupported);
    // A text message with nothing in it has nothing to draw either.
    expect(
      _message(body: '   ').toMessageData().kind,
      AppMessageKind.unsupported,
    );
  });

  test('video without a cached file still carries a preview attachment', () {
    final AppMessageData data = _message(
      type: 'video',
      body: null,
    ).toMessageData();

    expect(data.kind, AppMessageKind.video);
    expect(data.attachment?.mimeType, 'video/mp4');
    expect(data.attachment?.name, 'video.mp4');
  });

  test(
    'video poster path is wired when a thumbnail exists beside the file',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'poster-test',
      );
      addTearDown(() => temp.delete(recursive: true));

      final String videoPath = p.join(temp.path, 'clip.mp4');
      await File(videoPath).writeAsBytes(const <int>[0]);
      final String thumbPath = FileStorage.thumbnailPathFor(videoPath);
      await File(thumbPath).writeAsBytes(const <int>[0]);

      expect(
        _message(
          type: 'video',
          localMediaPath: videoPath,
        ).toMessageData().attachment?.posterPath,
        thumbPath,
      );
    },
  );

  test('media carries its file; a message without one carries none', () {
    expect(
      _message(
        type: 'image',
        mediaUrl: 'https://cdn.test/a.jpg',
      ).toMessageData().attachment?.url,
      'https://cdn.test/a.jpg',
    );
    expect(
      _message(
        type: 'image',
        localMediaPath: '/tmp/a.jpg',
      ).toMessageData().attachment?.localPath,
      '/tmp/a.jpg',
    );
    expect(_message().toMessageData().attachment, isNull);
  });

  test('the rest carries over as it is', () {
    final AppMessageData data = _message(isFromBot: true).toMessageData();

    expect(data.id, 'm1');
    expect(data.sentAt, testEpoch);
    expect(data.text, 'Hello');
    expect(data.authorId, 'u1');
    expect(data.isFromBot, isTrue);
  });
}
