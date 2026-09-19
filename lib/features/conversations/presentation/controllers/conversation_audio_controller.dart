import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../../design_system/design_system.dart';

/// Plays voice notes in a thread using [AppAudioController].
final class ConversationAudioController extends ChangeNotifier
    implements AppAudioController {
  ConversationAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscription = _player.onPlayerStateChanged.listen((_) => notifyListeners());
    _positionSubscription = _player.onPositionChanged.listen((Duration position) {
      _position = position;
      notifyListeners();
    });
    _durationSubscription = _player.onDurationChanged.listen((Duration duration) {
      _duration = duration;
      notifyListeners();
    });
  }

  final AudioPlayer _player;
  AppAttachmentData? _current;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  late final StreamSubscription<PlayerState> _subscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;

  @override
  AppAudioPlayback playbackOf(AppAttachmentData attachment) {
    if (_current != attachment) {
      return AppAudioPlayback(duration: _duration);
    }

    return AppAudioPlayback(
      playing: _playing,
      position: _position,
      duration: _duration,
    );
  }

  @override
  Future<void> toggle(AppAttachmentData attachment) async {
    if (_current == attachment && _playing) {
      await _player.pause();
      _playing = false;
      notifyListeners();
      return;
    }

    if (_current != attachment) {
      await _player.stop();
      _current = attachment;
      _position = Duration.zero;
      _duration = null;

      final String? source = attachment.localPath ?? attachment.url;
      if (source == null) return;

      if (attachment.localPath != null) {
        await _player.play(DeviceFileSource(source));
      } else {
        await _player.play(UrlSource(source));
      }
    } else {
      await _player.resume();
    }

    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _player.dispose();
    super.dispose();
  }
}
