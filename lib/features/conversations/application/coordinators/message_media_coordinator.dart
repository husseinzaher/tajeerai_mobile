import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/storage/file_storage.dart';
import '../../data/remote/conversation_media_port.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/value_objects/outbound_media.dart';

/// Caches inbound message attachments on disk.
///
/// The thread reads from the database; this coordinator fills
/// [Message.localMediaPath] so media is available offline after the first
/// download, matching the web inbox's media cache.
class MessageMediaCoordinator {
  MessageMediaCoordinator({
    required MessageRepository messages,
    required ConversationMediaPort remote,
    required FileStorage storage,
    required Logger logger,
  }) : _messages = messages,
       _remote = remote,
       _storage = storage,
       _logger = logger;

  final MessageRepository _messages;
  final ConversationMediaPort _remote;
  final FileStorage _storage;
  final Logger _logger;

  final Set<String> _inFlight = <String>{};

  /// Downloads any uncached media in [messages].
  Future<void> cacheAll(Iterable<Message> messages) async {
    for (final Message message in messages) {
      await cacheOne(message);
    }
  }

  /// Downloads one message's attachment when needed.
  Future<void> cacheOne(Message message) async {
    if (!message.isInbound) return;
    if (!OutboundMedia.supportedTypes.contains(message.type) &&
        message.type != 'sticker') {
      return;
    }

    final String? existing = message.localMediaPath;

    if (existing != null && _storage.exists(existing)) return;

    if (_inFlight.contains(message.id)) return;

    _inFlight.add(message.id);

    try {
      final bytes = await _remote.download(
        conversationId: message.conversationId,
        messageId: message.id,
      );

      if (bytes.isEmpty || _looksLikeJsonError(bytes)) return;

      final path = await _storage.writeCachedMedia(
        '${message.id}${_extensionFor(message.type)}',
        bytes,
      );

      await _messages.updateMedia(messageId: message.id, localMediaPath: path);
    } on Object catch (error, stackTrace) {
      _logger.debug(
        'media cache failed',
        data: <String, Object?>{'messageId': message.id, 'error': error},
      );
      _logger.debug(
        'media cache stack',
        data: <String, Object?>{'trace': '$stackTrace'},
      );
    } finally {
      _inFlight.remove(message.id);
    }
  }

  static bool _looksLikeJsonError(List<int> bytes) {
    if (bytes.isEmpty) return true;

    final int first = bytes.first;

    return first == 0x7b || first == 0x5b;
  }

  static String _extensionFor(String type) => switch (type) {
    'image' || 'sticker' => '.jpg',
    'video' => '.mp4',
    'audio' => '.m4a',
    _ => '.bin',
  };
}
