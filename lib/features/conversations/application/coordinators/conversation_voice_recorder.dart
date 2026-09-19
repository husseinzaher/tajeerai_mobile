import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records a voice note to a temporary file.
///
/// Lives in the application layer because it orchestrates a device workflow the
/// design system must not import.
final class ConversationVoiceRecorder {
  ConversationVoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  String? _path;
  DateTime? _startedAt;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;

  bool get isRecording => _path != null;

  /// Fires about once a second while recording.
  void Function(Duration elapsed)? onElapsed;

  Future<bool> start() async {
    if (_path != null) return false;

    if (!await _recorder.hasPermission()) return false;

    final Directory temp = await getTemporaryDirectory();
    final String path = p.join(
      temp.path,
      'voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    _path = path;
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final DateTime? started = _startedAt;
      if (started == null) return;
      _elapsed = DateTime.now().difference(started);
      onElapsed?.call(_elapsed);
    });

    return true;
  }

  /// Stops recording and returns the file path, or null when nothing recorded.
  Future<String?> stop() async {
    final String? path = _path;
    if (path == null) return null;

    await _recorder.stop();
    _tick?.cancel();
    _tick = null;
    _path = null;
    _startedAt = null;
    _elapsed = Duration.zero;

    if (!File(path).existsSync()) return null;

    return path;
  }

  Future<void> cancel() async {
    final String? path = _path;
    if (path == null) return;

    await _recorder.stop();
    _tick?.cancel();
    _tick = null;
    _path = null;
    _startedAt = null;
    _elapsed = Duration.zero;

    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
