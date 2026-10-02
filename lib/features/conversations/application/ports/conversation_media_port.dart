/// What `POST /v1/conversations/:id/media` returns.
final class UploadedConversationMedia {
  const UploadedConversationMedia({
    required this.mediaId,
    required this.type,
    required this.filename,
    required this.mimeType,
  });

  final String mediaId;
  final String type;
  final String filename;
  final String mimeType;
}

/// Upload and download ports for conversation attachments.
abstract interface class ConversationMediaPort {
  Future<UploadedConversationMedia> upload({
    required String conversationId,
    required String filePath,
    required String filename,
    String? mimeType,
  });

  Future<List<int>> download({
    required String conversationId,
    required String messageId,
  });
}
