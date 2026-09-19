import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../design_system/design_system.dart';
import '../../application/coordinators/message_media_coordinator.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';

/// Plays conversation videos inline inside message bubbles.
final class ConversationVideoController extends ChangeNotifier
    implements AppVideoController {
  ConversationVideoController({
    required MessageMediaCoordinator cache,
    required MessageRepository messages,
  }) : _cache = cache,
       _messages = messages;

  final MessageMediaCoordinator _cache;
  final MessageRepository _messages;

  VideoPlayerController? _player;
  String? _currentMessageId;
  bool _loading = false;

  @override
  AppVideoPlayback playbackOf(String messageId) {
    if (_currentMessageId != messageId || _player == null) {
      return AppVideoPlayback(
        loading: _loading && _currentMessageId == messageId,
      );
    }

    return AppVideoPlayback(
      playing: _player!.value.isPlaying,
      loading: _loading,
      initialized: _player!.value.isInitialized,
    );
  }

  @override
  Widget? surfaceFor(String messageId) {
    if (_currentMessageId != messageId || _player == null) return null;
    if (!_player!.value.isInitialized) return null;

    return VideoPlayer(_player!);
  }

  @override
  Future<void> toggle({
    required String messageId,
    required AppAttachmentData attachment,
  }) async {
    if (_currentMessageId == messageId &&
        _player != null &&
        _player!.value.isInitialized &&
        _player!.value.isPlaying) {
      await _player!.pause();
      notifyListeners();
      return;
    }

    if (_currentMessageId == messageId &&
        _player != null &&
        _player!.value.isInitialized &&
        !_player!.value.isPlaying) {
      await _player!.play();
      notifyListeners();
      return;
    }

    await _start(messageId: messageId, attachment: attachment);
  }

  Future<void> _start({
    required String messageId,
    required AppAttachmentData attachment,
  }) async {
    await _disposePlayer();

    _currentMessageId = messageId;
    _loading = true;
    notifyListeners();

    try {
      final Message? message = await _messages.findMessage(messageId);
      if (message == null) return;

      final VideoPlayerController controller = await _controllerFor(
        message: message,
        attachment: attachment,
      );

      _player = controller..addListener(notifyListeners);

      await _player!.initialize();
      await _player!.setLooping(true);
      await _player!.play();
    } on Object {
      await _disposePlayer();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<VideoPlayerController> _controllerFor({
    required Message message,
    required AppAttachmentData attachment,
  }) async {
    String? path = attachment.localPath ?? message.localMediaPath;

    if (path == null || !File(path).existsSync()) {
      path = await _cache.ensureCached(message);
    }

    if (path != null && File(path).existsSync()) {
      return VideoPlayerController.file(File(path));
    }

    final String? url = attachment.url ?? message.mediaUrl;
    if (url == null || url.isEmpty) {
      throw StateError('The video is not available on this device.');
    }

    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  Future<void> _disposePlayer() async {
    final VideoPlayerController? player = _player;
    _player = null;
    _currentMessageId = null;
    _loading = false;

    if (player != null) {
      player.removeListener(notifyListeners);
      await player.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await _disposePlayer();
    super.dispose();
  }
}
