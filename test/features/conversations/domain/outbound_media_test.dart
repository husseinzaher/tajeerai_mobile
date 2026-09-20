import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/message_content.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/outbound_media.dart';

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

    test('rejects a type the backend has no vocabulary for', () {
      expect(
        () => OutboundMedia.parse(
          type: 'sticker',
          localPath: '/tmp/sticker.webp',
          filename: 'sticker.webp',
          mimeType: 'image/webp',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('keeps a caption, trimmed the way a text message would be', () {
      final media = OutboundMedia.parse(
        type: 'image',
        localPath: '/tmp/photo.jpg',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        rawCaption: '  هذا اللون  ',
      );

      expect(media.caption, 'هذا اللون');
    });

    test('a caption of only whitespace is no caption, not an error', () {
      // The composer sends what the field holds. An untouched caption field
      // must not turn a perfectly good photo into a validation failure.
      final media = OutboundMedia.parse(
        type: 'image',
        localPath: '/tmp/photo.jpg',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        rawCaption: '   ',
      );

      expect(media.caption, isNull);
    });

    test('a caption past the provider limit names the rule it broke', () {
      try {
        OutboundMedia.parse(
          type: 'image',
          localPath: '/tmp/photo.jpg',
          filename: 'photo.jpg',
          mimeType: 'image/jpeg',
          rawCaption: 'x' * (MessageContent.maxLength + 1),
        );
        fail('a caption over the limit must not be accepted');
      } on ValidationFailure catch (failure) {
        expect(failure.fieldErrors['body'], <String>['message.tooLong']);
      }
    });
  });

  group('railPreview', () {
    test('names the kind of attachment, and a document by its filename', () {
      OutboundMedia media(String type) => OutboundMedia(
        type: type,
        localPath: '/tmp/file',
        filename: 'contract.pdf',
        mimeType: 'application/pdf',
      );

      expect(media('image').railPreview(), 'Photo');
      expect(media('video').railPreview(), 'Video');
      expect(media('audio').railPreview(), 'Voice message');
      expect(media('document').railPreview(), 'contract.pdf');
      // A type from a newer server than this build knows about.
      expect(media('sticker').railPreview(), 'contract.pdf');
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
