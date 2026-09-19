import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/network/http_client.dart';
import '../../../../infrastructure/network/http_exception.dart';

import 'conversation_media_port.dart';

/// HTTP transport for conversation attachments.
///
/// Upload and download are HTTP because they are streamed bodies, not socket
/// frames — see `ARCHITECTURE.md` §11.
class ConversationMediaRemoteDataSource implements ConversationMediaPort {
  const ConversationMediaRemoteDataSource(this._http);

  /// Large videos need more time to stream than text API calls.
  static const Duration uploadTimeout = Duration(minutes: 5);

  final HttpClient _http;

  /// `POST /v1/conversations/:id/media`.
  @override
  Future<UploadedConversationMedia> upload({
    required String conversationId,
    required String filePath,
    required String filename,
    String? mimeType,
  }) async {
    try {
      final Map<String, Object?> body = await _http.postMultipart(
        '/v1/conversations/$conversationId/media',
        filePath: filePath,
        filename: filename,
        mimeType: mimeType,
        sendTimeout: uploadTimeout,
        receiveTimeout: uploadTimeout,
      );

      final mediaId = body['mediaId']?.toString();
      final type = body['type']?.toString();

      if (mediaId == null || mediaId.isEmpty || type == null || type.isEmpty) {
        throw const FormatException('Upload acknowledgement was incomplete.');
      }

      return UploadedConversationMedia(
        mediaId: mediaId,
        type: type,
        filename: body['filename']?.toString() ?? filename,
        mimeType:
            body['mimeType']?.toString() ??
            mimeType ??
            'application/octet-stream',
      );
    } on HttpException catch (error) {
      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected upload response.',
        cause: error,
      );
    }
  }

  /// `GET /v1/conversations/:id/messages/:messageId/media`.
  @override
  Future<List<int>> download({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final bytes = await _http.getBytes(
        '/v1/conversations/$conversationId/messages/$messageId/media',
      );

      return bytes;
    } on HttpException catch (error) {
      throw error.toFailure();
    }
  }
}
