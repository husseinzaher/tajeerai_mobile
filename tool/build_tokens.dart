// Design token generator.
//
// Reads `design/tokens.json` -- the mobile design system's single source of
// truth -- and writes `lib/app/theme/tokens.g.dart`.
//
//     dart run tool/build_tokens.dart            regenerate
//     dart run tool/build_tokens.dart --check     fail if the file is stale
//
// Exit codes are distinct on purpose, because the two failures need different
// responses: 1 means the generated file does not match the token file (run
// `make tokens`), 2 means the token file itself is malformed (fix the token
// file). Reporting both as 1 sends people to the wrong place.
//
// The generated file is gitignored, like every other `.g.dart` here, and is
// produced by `make generate` before anything compiles. `--check` therefore
// guards a local edit rather than a stale commit: CI cannot have one.

import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';

import 'tokens/dart_emitter.dart';
import 'tokens/token_document.dart';
import 'tokens/token_format_exception.dart';

const String _defaultTokens = 'design/tokens.json';
const String _defaultOutput = 'lib/app/theme/tokens.g.dart';

Future<void> main(List<String> arguments) async {
  final bool check = arguments.contains('--check');
  final bool quiet = arguments.contains('--quiet');
  final bool verbose = arguments.contains('--verbose');

  final String tokensPath = _option(arguments, '--tokens') ?? _defaultTokens;
  final String outputPath = _option(arguments, '--out') ?? _defaultOutput;

  final File tokensFile = File(tokensPath);
  if (!tokensFile.existsSync()) {
    stderr.writeln('No token file at $tokensPath. Run from the package root.');
    exit(2);
  }

  final String source;
  try {
    final Object? decoded = jsonDecode(tokensFile.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      stderr.writeln('$tokensPath: expected a JSON object at the root.');
      exit(2);
    }
    final TokenDocument document = TokenDocument.parse(decoded);
    if (verbose) {
      final int presets = document.colors.length;
      final int perTheme = document.colors.values.first['light']!.length;
      stdout.writeln(
        'Parsed $presets presets x 2 themes x $perTheme colours, '
        '${document.channels['light']!.length} channel colours x 2, '
        '${document.type.length} type steps, '
        '${document.space.length} spacing steps, '
        '${document.radius.length} radii, '
        '${document.elevation.values.first['light']!.length} elevation levels '
        'x 2 themes x $presets presets.',
      );
    }
    source = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(DartEmitter.emit(document));
  } on TokenFormatException catch (error) {
    stderr
      ..writeln('$tokensPath is not a valid token file.')
      ..writeln('  ${error.pointer}')
      ..writeln('    ${error.message}');
    exit(2);
  } on FormatException catch (error) {
    stderr.writeln('$tokensPath: ${error.message}');
    exit(2);
  }

  final File output = File(outputPath);

  if (check) {
    if (!output.existsSync()) {
      stderr
        ..writeln('$outputPath does not exist.')
        ..writeln('  run: make tokens');
      exit(1);
    }
    final String existing = _normalise(output.readAsStringSync());
    if (existing == _normalise(source)) {
      if (!quiet) {
        stdout.writeln('$outputPath is up to date with $tokensPath.');
      }
      exit(0);
    }
    stderr
      ..writeln('$outputPath is stale.')
      ..writeln('  ${_firstDifference(existing, _normalise(source))}')
      ..writeln('  run: make tokens');
    exit(1);
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(source);
  if (!quiet) {
    stdout.writeln('Wrote $outputPath from $tokensPath.');
  }
}

String? _option(List<String> arguments, String name) {
  for (final String argument in arguments) {
    if (argument.startsWith('$name=')) {
      return argument.substring(name.length + 1);
    }
  }
  return null;
}

/// Line endings differ between checkouts; a token value does not.
String _normalise(String source) => source.replaceAll('\r\n', '\n');

/// Names the first line that differs, so the remedy is obvious without
/// diffing a two-thousand-line generated file by eye.
String _firstDifference(String existing, String generated) {
  final List<String> a = existing.split('\n');
  final List<String> b = generated.split('\n');
  for (int line = 0; line < a.length && line < b.length; line++) {
    if (a[line] != b[line]) {
      return 'first difference at line ${line + 1}: '
          'on disk "${a[line].trim()}", generated "${b[line].trim()}"';
    }
  }
  return 'the files differ in length: ${a.length} lines on disk, ${b.length} generated';
}
