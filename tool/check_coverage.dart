// Coverage gate.
//
//     flutter test --coverage
//     dart run tool/check_coverage.dart
//
// Exits non-zero when overall coverage, or any business-critical area, falls
// below its floor.
//
// With `--detail <path prefix>` it reports instead of gating: every file under
// that prefix, worst first, with the lines no test reached. That is the list to
// work from when an area is under its floor -- the gate says which area, this
// says which behaviour.
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
  // The contact directory a caller card answers from: a rule that is wrong
  // here shows up as the wrong person's name over a ringing phone.
  'lib/features/customers/domain/': 90,
  // The walk that keeps that directory complete -- resume, pacing and the
  // reconciliation that deletes.
  'lib/features/customers/application/': 85,
  'lib/infrastructure/database/daos/': 85,
  'lib/infrastructure/realtime/': 85,
  'lib/failures/': 90,
};

/// Files excluded from the calculation, each for a stated reason.
///
/// An exclusion is a claim that a file cannot be meaningfully unit-tested, not
/// a way to make a number look better. Every entry below is one of:
///
/// - **generated output** -- `.g.dart`, `.freezed.dart`, and the `.steps.dart`
///   schema snapshots `make migrations` writes. The generator's
///   responsibility, and a test would assert on its behaviour rather than
///   this project's. The migration steps written against those snapshots are
///   not generated, and `migration_test.dart` runs them;
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
      path.endsWith('.steps.dart') ||
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

  if (arguments.isNotEmpty && arguments.first == '--detail') {
    if (arguments.length < 2) {
      stderr.writeln('Usage: check_coverage.dart --detail <path prefix>');
      exit(2);
    }

    _detail(records, arguments[1]);
    exit(0);
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

/// Every file under [prefix], least covered first, and the lines nothing ran.
void _detail(Map<String, _Record> records, String prefix) {
  final matching =
      records.entries
          .where(
            (MapEntry<String, _Record> record) => record.key.startsWith(prefix),
          )
          .toList()
        ..sort((MapEntry<String, _Record> a, MapEntry<String, _Record> b) {
          return _percentage(
            a.value.hit,
            a.value.found,
          ).compareTo(_percentage(b.value.hit, b.value.found));
        });

  if (matching.isEmpty) {
    stderr.writeln('No coverage records under $prefix.');
    exit(2);
  }

  var found = 0;
  var hit = 0;

  for (final entry in matching) {
    found += entry.value.found;
    hit += entry.value.hit;
  }

  stdout.writeln(prefix);
  stdout.writeln('-' * 72);

  for (final entry in matching) {
    final record = entry.value;
    final percentage = _percentage(record.hit, record.found);

    stdout.writeln(
      '${percentage.toStringAsFixed(1).padLeft(6)}%  '
      '${record.hit.toString().padLeft(4)}/${record.found.toString().padRight(4)}  '
      '${entry.key.substring(prefix.length)}',
    );

    if (record.uncovered.isNotEmpty) {
      stdout.writeln('          uncovered: ${_ranges(record.uncovered)}');
    }
  }

  stdout.writeln('-' * 72);
  stdout.writeln(
    '${_percentage(hit, found).toStringAsFixed(1)}%  ($hit/$found lines)',
  );
}

/// `1 2 3 9` as `1-3, 9`, because a run of lines is one untested branch.
String _ranges(List<int> lines) {
  final parts = <String>[];
  var start = lines.first;
  var previous = start;

  for (final line in lines.skip(1)) {
    if (line == previous + 1) {
      previous = line;

      continue;
    }

    parts.add(start == previous ? '$start' : '$start-$previous');
    start = line;
    previous = line;
  }

  parts.add(start == previous ? '$start' : '$start-$previous');

  return parts.join(', ');
}

double _percentage(int hit, int found) => found == 0 ? 100 : hit / found * 100;

/// Reads the `SF`/`DA` records of an lcov report.
Map<String, _Record> _parse(List<String> lines) {
  final records = <String, _Record>{};

  String? current;
  var found = 0;
  var hit = 0;
  var uncovered = <int>[];

  void flush() {
    final path = current;

    if (path != null && !_isExcluded(path)) {
      final existing = records[path];

      records[path] = _Record(
        found: (existing?.found ?? 0) + found,
        hit: (existing?.hit ?? 0) + hit,
        uncovered: <int>[...?existing?.uncovered, ...uncovered]..sort(),
      );
    }

    current = null;
    found = 0;
    hit = 0;
    uncovered = <int>[];
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

      if ((int.tryParse(parts[1]) ?? 0) > 0) {
        hit += 1;
      } else {
        final line = int.tryParse(parts[0]);

        if (line != null) uncovered.add(line);
      }

      continue;
    }

    if (line.trim() == 'end_of_record') flush();
  }

  flush();

  return records;
}

class _Record {
  const _Record({
    required this.found,
    required this.hit,
    this.uncovered = const <int>[],
  });

  final int found;
  final int hit;

  /// The lines no test reached, in file order.
  final List<int> uncovered;
}
