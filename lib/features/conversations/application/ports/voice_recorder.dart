/// Records a voice note to a file on the device.
///
/// An application port rather than a plugin call in the screen: the thread
/// screen starts, stops and cancels a recording, and it must not import the
/// recorder plugin or the temp directory to do it. `RecordVoiceRecorder` in
/// `infrastructure/adapters/conversations/device/` implements this over the
/// `record` plugin, and the composition root hands the screen a factory, so a
/// test can hand it one that records nothing.
abstract interface class VoiceRecorder {
  /// How long the current recording has run. Zero when nothing is recording.
  Duration get elapsed;

  bool get isRecording;

  /// Called about once a second while recording, so a counter can move.
  void Function(Duration elapsed)? onElapsed;

  /// Begins recording. False when it could not -- most often because the
  /// microphone permission was refused -- and never throws for that.
  Future<bool> start();

  /// Stops recording and returns the file, or null when nothing was written.
  Future<String?> stop();

  /// Stops recording and deletes whatever was written.
  Future<void> cancel();

  /// Cancels any recording in flight and releases the encoder.
  Future<void> dispose();
}
