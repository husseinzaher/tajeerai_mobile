import 'package:TajeerAi/features/conversations/data/remote/conversation_media_port.dart';

class FakeConversationMediaRemote implements ConversationMediaPort {
  int uploadCalls = 0;
  int downloadCalls = 0;
  Object? failureToThrow;

  /// What the next download answers with. A PNG header by default; set it to
  /// `[]` for an empty body, or to `{` for the JSON an error page returns.
  List<int> nextDownload = const <int>[0x89, 0x50, 0x4e, 0x47];

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
    downloadCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return nextDownload;
  }
}
