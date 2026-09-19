import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/conversations/domain/value_objects/outbound_media.dart';

void main() {
  group('OutboundMedia.parse', () {
    test('accepts a voice note without a caption', () {
      final media = OutboundMedia.parse(
        type: 'audio',
        localPath: '/tmp/voice.m4a',
        filename: 'voice.m4a',
        mimeType: 'audio/mp4',
      );

      expect(media.type, 'audio');
      expect(media.caption, isNull);
      expect(media.railPreview(), 'Voice message');
    });

    test('rejects an empty local path', () {
      expect(
        () => OutboundMedia.parse(
          type: 'image',
          localPath: '   ',
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('messageTypeFromMime', () {
    test('maps common mime types', () {
      expect(messageTypeFromMime('image/jpeg'), 'image');
      expect(messageTypeFromMime('video/mp4'), 'video');
      expect(messageTypeFromMime('audio/mp4'), 'audio');
      expect(messageTypeFromMime('application/pdf'), 'document');
    });
  });
}
