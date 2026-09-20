import 'package:TajeerAi/features/conversations/data/remote/conversation_media_port.dart';

class FakeConversationMediaRemote implements ConversationMediaPort {
  int uploadCalls = 0;
  Object? failureToThrow;

  UploadedConversationMedia nextUpload = const UploadedConversationMedia(
    mediaId: 'media-1',
    type: 'image',
    filename: 'photo.jpg',
    mimeType: 'image/jpeg',
  );

  @override
  Future<UploadedConversationMedia> upload({
    required String conversationId,
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    uploadCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return nextUpload;
  }

  @override
  Future<List<int>> download({
    required String conversationId,
    required String messageId,
  }) async {
    final failure = failureToThrow;

    if (failure != null) throw failure;

    return <int>[0x89, 0x50, 0x4e, 0x47];
  }
}
