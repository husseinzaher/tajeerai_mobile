import '../../../../failures/app_failure.dart';
import 'message_content.dart';

/// An outbound attachment before it reaches the server.
///
/// Validates caption length with the same rules as text messages. The file
/// itself is checked only for presence — size limits are enforced by the API
/// on upload.
final class OutboundMedia {
  const OutboundMedia({
    required this.type,
    required this.localPath,
    required this.filename,
    required this.mimeType,
    this.caption,
  });

  final String type;
  final String localPath;
  final String filename;
  final String mimeType;
  final String? caption;

  static const Set<String> supportedTypes = <String>{
    'image',
    'video',
    'audio',
    'document',
  };

  /// Parses and validates an outbound attachment.
  static OutboundMedia parse({
    required String type,
    required String localPath,
    required String filename,
    required String mimeType,
    String? rawCaption,
  }) {
    if (localPath.trim().isEmpty) {
      throw const ValidationFailure(
        message: 'The attachment could not be sent.',
        fieldErrors: <String, List<String>>{
          'attachment': <String>['message.attachmentMissing'],
        },
      );
    }

    if (!supportedTypes.contains(type)) {
      throw const ValidationFailure(
        message: 'This attachment type is not supported.',
      );
    }

    String? caption;

    if (rawCaption != null && rawCaption.trim().isNotEmpty) {
      final parsed = MessageContent.parse(rawCaption);

      caption = switch (parsed) {
        ValidMessageContent(:final content) => content.value,
        InvalidMessageContent(:final error) => throw ValidationFailure(
          message: 'The caption could not be sent.',
          fieldErrors: <String, List<String>>{
            'body': <String>[
              switch (error) {
                MessageContentError.empty => 'message.empty',
                MessageContentError.tooLong => 'message.tooLong',
              },
            ],
          },
        ),
      };
    }

    return OutboundMedia(
      type: type,
      localPath: localPath,
      filename: filename,
      mimeType: mimeType,
      caption: caption,
    );
  }

  /// A one-line preview for the conversation rail.
  String railPreview() => switch (type) {
    'image' => 'Photo',
    'video' => 'Video',
    'audio' => 'Voice message',
    'document' => filename,
    _ => filename,
  };
}

/// Maps a picked file's MIME type to the backend's message type vocabulary.
String messageTypeFromMime(String? mimeType) {
  final String type = mimeType?.toLowerCase() ?? '';

  if (type.startsWith('image/')) return 'image';
  if (type.startsWith('video/')) return 'video';
  if (type.startsWith('audio/')) return 'audio';

  return 'document';
}
