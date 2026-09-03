// Coverage gate.
//
//     flutter test --coverage
//     dart run tool/check_coverage.dart
//
// Exits non-zero when overall coverage, or any business-critical area, falls
// below its floor.
//
// ## Why two thresholds
//
// A single global percentage lets weakly-tested business logic hide behind
// well-tested boilerplate. The areas listed in [_criticalAreas] are the ones
// where a bug is expensive -- domain rules, synchronisation, the outbox,
// realtime handling, authentication -- and each carries its own, higher floor.
//
// Coverage is a guardrail, not a goal. A test written only to move this number
// is worse than the gap it fills.

import 'dart:io';

/// The floor for the project as a whole.
const double _globalThreshold = 80;

/// Paths that must clear a higher bar, and what that bar is.
const Map<String, double> _criticalAreas = <String, double>{
  'lib/features/auth/domain/': 90,
  'lib/features/conversations/domain/': 90,
  'lib/features/conversations/application/': 85,
  'lib/features/conversations/realtime/': 85,
  'lib/features/auth/application/': 85,
  'lib/infrastructure/database/daos/': 85,
  'lib/infrastructure/realtime/': 85,
  'lib/failures/': 90,
};

/// Files excluded from the calculation, each for a stated reason.
///
/// An exclusion is a claim that a file cannot be meaningfully unit-tested, not
/// a way to make a number look better. Every entry below is one of:
///
/// - **generated output** -- the builder's responsibility, and a test would
///   assert on a generator's behaviour rather than this project's;
/// - **`main.dart`** -- the composition root. Covering it means booting the
///   whole app to satisfy a number; `dependencies_test.dart` covers the graph
///   it wires instead;
/// - **`app.dart`** -- the same, for the widget-level composition;
/// - **drift table declarations** -- column getters the generator reads. Their
///   behaviour is exercised through the DAO tests, which run against a real
///   SQLite engine;
/// - **`socket_connection.dart`** -- the Socket.IO implementation of
///   `SocketClient`. Exercising it needs a live Socket.IO server, so a unit
///   test could only assert against a mock of the library. Everything built on
///   it is tested through the `SocketClient` interface with a fake transport.
///   See ARCHITECTURE.md -> Remaining work for the integration test this owes.
bool _isExcluded(String path) {
  const excludedFiles = <String>{
    'lib/main.dart',
    'lib/app/app.dart',
    'lib/infrastructure/realtime/socket_connection.dart',
  };

  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('_tables.dart') ||
      excludedFiles.contains(path);
}

void main(List<String> arguments) {
  final file = File('coverage/lcov.info');

  if (!file.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run `flutter test --coverage` first.',
    );
    exit(2);
  }

  final records = _parse(file.readAsLinesSync());

  if (records.isEmpty) {
    stderr.writeln('No coverage records found in coverage/lcov.info.');
    exit(2);
  }

  var totalFound = 0;
  var totalHit = 0;

  for (final record in records.values) {
    totalFound += record.found;
    totalHit += record.hit;
  }

  final global = _percentage(totalHit, totalFound);
  var failed = false;

  stdout.writeln('Coverage');
  stdout.writeln('-' * 60);
  stdout.writeln(
    'overall  ${global.toStringAsFixed(1)}%  '
    '($totalHit/$totalFound lines)  floor ${_globalThreshold.toInt()}%',
  );

  if (global < _globalThreshold) failed = true;

  stdout.writeln('-' * 60);

  for (final entry in _criticalAreas.entries) {
    final area = records.entries.where(
      (record) => record.key.startsWith(entry.key),
    );

    if (area.isEmpty) {
      stderr.writeln('No coverage data for ${entry.key} -- is it still there?');
      failed = true;

      continue;
    }

    var found = 0;
    var hit = 0;

    for (final record in area) {
      found += record.value.found;
      hit += record.value.hit;
    }

    final percentage = _percentage(hit, found);
    final ok = percentage >= entry.value;

    if (!ok) failed = true;

    stdout.writeln(
      '${ok ? 'PASS' : 'FAIL'}  ${percentage.toStringAsFixed(1).padLeft(5)}%  '
      'floor ${entry.value.toInt()}%  ${entry.key}',
    );
  }

  stdout.writeln('-' * 60);

  if (failed) {
    stderr.writeln(
      'Coverage is below the required floor. Add tests for the behaviour that '
      'is not exercised -- do not lower the threshold.',
    );
    exit(1);
  }

  stdout.writeln('Coverage thresholds met.');
  exit(0);
}

double _percentage(int hit, int found) => found == 0 ? 100 : hit / found * 100;

/// Reads the `SF`/`DA` records of an lcov report.
Map<String, _Record> _parse(List<String> lines) {
  final records = <String, _Record>{};

  String? current;
  var found = 0;
  var hit = 0;

  void flush() {
    final path = current;

    if (path != null && !_isExcluded(path)) {
      final existing = records[path];

      records[path] = _Record(
        found: (existing?.found ?? 0) + found,
        hit: (existing?.hit ?? 0) + hit,
      );
    }

    current = null;
    found = 0;
    hit = 0;
  }

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      flush();
      current = line.substring(3).replaceAll(r'\', '/');

      continue;
    }

    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');

      if (parts.length < 2) continue;

      found += 1;
      if ((int.tryParse(parts[1]) ?? 0) > 0) hit += 1;

      continue;
    }

    if (line.trim() == 'end_of_record') flush();
  }

  flush();

  return records;
}

class _Record {
  const _Record({required this.found, required this.hit});

  final int found;
  final int hit;
}
