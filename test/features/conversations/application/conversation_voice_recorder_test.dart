import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:record/record.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/conversation_voice_recorder.dart';

void main() {
  late Directory temp;
  late _FakeAudioRecorder recorder;
  late ConversationVoiceRecorder subject;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tajeer-voice-');
    PathProviderPlatform.instance = _TempPathProvider(temp);
    recorder = _FakeAudioRecorder();
    subject = ConversationVoiceRecorder(recorder: recorder);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('start', () {
    test('records to a file of its own and says it began', () async {
      expect(await subject.start(), isTrue);

      expect(subject.isRecording, isTrue);
      expect(recorder.startedAt, isNotNull);
      expect(recorder.startedAt, startsWith(temp.path));
      expect(recorder.startedAt, endsWith('.m4a'));
      expect(recorder.config?.encoder, AudioEncoder.aacLc);
    });

    test('without the microphone permission it refuses, quietly', () async {
      // The member is shown the permission prompt by the OS; a recorder that
      // reported success here would leave them holding a button that records
      // nothing.
      recorder.permitted = false;

      expect(await subject.start(), isFalse);
      expect(subject.isRecording, isFalse);
      expect(recorder.startedAt, isNull);
    });

    test('a second start while recording is ignored, not restarted', () async {
      await subject.start();
      final String? first = recorder.startedAt;

      expect(await subject.start(), isFalse);
      expect(recorder.startedAt, first);
    });
  });

  group('stop', () {
    test('returns the file when one was written', () async {
      await subject.start();
      File(recorder.startedAt!).writeAsBytesSync(<int>[1, 2, 3]);

      expect(await subject.stop(), recorder.startedAt);
      expect(subject.isRecording, isFalse);
      expect(subject.elapsed, Duration.zero);
      expect(recorder.stops, 1);
    });

    test('returns nothing when the encoder wrote no file', () async {
      // A tap too short to produce audio: there is a path, and nothing at it.
      await subject.start();

      expect(await subject.stop(), isNull);
      expect(subject.isRecording, isFalse);
    });

    test(
      'stopping when nothing is recording never touches the recorder',
      () async {
        expect(await subject.stop(), isNull);
        expect(recorder.stops, 0);
      },
    );
  });

  group('cancel', () {
    test('stops and deletes what was recorded', () async {
      await subject.start();
      final String path = recorder.startedAt!;
      File(path).writeAsBytesSync(<int>[1]);

      await subject.cancel();

      expect(File(path).existsSync(), isFalse);
      expect(subject.isRecording, isFalse);
      expect(recorder.stops, 1);
    });

    test('survives a recording that never produced a file', () async {
      await subject.start();

      await subject.cancel();

      expect(subject.isRecording, isFalse);
    });

    test('cancelling when nothing is recording does nothing at all', () async {
      await subject.cancel();

      expect(recorder.stops, 0);
    });
  });

  group('dispose', () {
    test('cancels an in-flight recording and releases the encoder', () async {
      await subject.start();
      final String path = recorder.startedAt!;
      File(path).writeAsBytesSync(<int>[1]);

      await subject.dispose();

      expect(File(path).existsSync(), isFalse);
      expect(recorder.disposed, isTrue);
    });
  });

  testWidgets('while recording it reports elapsed time about once a second', (
    WidgetTester tester,
  ) async {
    // Driven through the test binding's clock: the ticker is what moves the
    // counter under the composer's record button.
    final List<Duration> reported = <Duration>[];
    subject.onElapsed = reported.add;

    await subject.start();
    await tester.pump(const Duration(seconds: 3));

    expect(reported, hasLength(3));

    await subject.stop();
    reported.clear();
    await tester.pump(const Duration(seconds: 2));

    expect(
      reported,
      isEmpty,
      reason: 'the ticker must stop with the recording',
    );
  });
}

class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this.temp);

  final Directory temp;

  @override
  Future<String?> getTemporaryPath() async => temp.path;
}

/// The `record` plugin's recorder, with the microphone taken out.
///
/// `noSuchMethod` rather than eighteen stubs: this fake claims only the four
/// members the coordinator uses, and anything else it reaches for fails the
/// test rather than quietly answering null.
class _FakeAudioRecorder implements AudioRecorder {
  bool permitted = true;
  bool disposed = false;
  int stops = 0;
  String? startedAt;
  RecordConfig? config;

  @override
  Future<bool> hasPermission({bool request = true}) async => permitted;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    this.config = config;
    startedAt = path;
  }

  @override
  Future<String?> stop() async {
    stops += 1;

    return startedAt;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'ConversationVoiceRecorder reached for '
      '${invocation.memberName}, which this fake does not model.',
    );
  }
}
