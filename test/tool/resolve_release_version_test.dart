import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolve_release_version shell tests pass', () async {
    final ProcessResult result = await Process.run('bash', <String>[
      'test/tool/resolve_release_version_test.sh',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
}
