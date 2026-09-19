import 'dart:io';

import 'package:open_filex/open_filex.dart';

import '../../application/coordinators/message_media_coordinator.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';

/// Opens a message attachment with the platform's default viewer.
abstract final class ConversationAttachmentOpener {
  static Future<OpenResult> open({
    required Message message,
    required MessageMediaCoordinator cache,
    required MessageRepository messages,
  }) async {
    String? path = message.localMediaPath;

    if (path == null || !File(path).existsSync()) {
      path = await cache.ensureCached(message);

      if (path == null) {
        final Message? refreshed = await messages.findMessage(message.id);

        path = refreshed?.localMediaPath;
      }
    }

    if (path != null && File(path).existsSync()) {
      return OpenFilex.open(path);
    }

    return OpenResult(
      type: ResultType.error,
      message: 'The attachment is not available on this device.',
    );
  }
}
