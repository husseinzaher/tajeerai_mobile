// Architecture Guard.
//
// Run it locally exactly as CI does:
//
//     dart run tool/check_architecture.dart
//
// Exits 0 when the codebase obeys the architecture, 1 when it does not.
// Violations are defects, not stylistic differences -- see CLAUDE.md.
//
// Add `--verbose` to list what was scanned, `--quiet` for the summary only.

import 'dart:io';

import 'architecture/architecture_rule.dart';
import 'architecture/import_analyzer.dart';
import 'architecture/path_classifier.dart';
import 'architecture/rules/design_system_boundary_rule.dart';
import 'architecture/rules/design_system_usage_rule.dart';
import 'architecture/rules/feature_boundary_rule.dart';
import 'architecture/rules/forbidden_directory_rule.dart';
import 'architecture/rules/http_transport_rule.dart';
import 'architecture/rules/infrastructure_rule.dart';
import 'architecture/rules/layer_dependency_rule.dart';
import 'architecture/rules/presentation_access_rule.dart';

/// Every per-file rule. Adding a rule is adding a line here.
const List<ArchitectureRule> _fileRules = <ArchitectureRule>[
  LayerDependencyRule(),
  FeatureBoundaryRule(),
  PresentationAccessRule(),
  InfrastructureRule(),
  GeneratedCodeRule(),
  DesignSystemBarrelRule(),
  DesignSystemAppAccessRule(),
  DesignSystemPackageRule(),
  RawDesignValueRule(),
  MaterialWidgetRule(),
  HttpTransportRule(),
];

/// Rules that inspect project structure rather than one file's imports.
const List<ProjectRule> _projectRules = <ProjectRule>[ForbiddenDirectoryRule()];

Future<void> main(List<String> arguments) async {
  final verbose = arguments.contains('--verbose');
  final quiet = arguments.contains('--quiet');

  final packageRoot = _findPackageRoot();

  if (packageRoot == null) {
    stderr.writeln('Could not find pubspec.yaml. Run from the package root.');
    exit(2);
  }

  final packageName = _readPackageName(packageRoot);
  final libraryDirectory = Directory('$packageRoot/lib');

  if (!libraryDirectory.existsSync()) {
    stderr.writeln('No lib/ directory found at $packageRoot.');
    exit(2);
  }

  final analyzer = ImportAnalyzer(
    packageRoot: packageRoot,
    packageName: packageName,
  );

  final files =
      libraryDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  final locations = files
      .map(
        (file) => PathClassifier.classify(
          file.path.substring(packageRoot.length + 1).replaceAll(r'\', '/'),
        ),
      )
      .toList(growable: false);

  final violations = <Violation>[];

  // Structural rules first: a forbidden directory explains a lot of the
  // import violations that would otherwise follow it.
  for (final rule in _projectRules) {
    violations.addAll(rule.checkProject(locations));
  }

  const failuresRule = ForbiddenDirectoryRule();

  for (var index = 0; index < files.length; index++) {
    final file = files[index];
    final location = locations[index];

    if (verbose) {
      stdout.writeln('scanning ${location.path} [${location.layer.name}]');
    }

    final List<ResolvedImport> imports;
    final String source;

    try {
      imports = analyzer.analyze(file);
      source = file.readAsStringSync();
    } on FileSystemException catch (error) {
      stderr.writeln('Could not read ${location.path}: ${error.message}');
      exit(2);
    }

    final context = ArchitectureContext(
      file: location,
      imports: imports,
      allFiles: locations,
      source: source,
    );

    for (final rule in _fileRules) {
      violations.addAll(rule.check(context));
    }

    violations.addAll(failuresRule.checkFailuresPurity(context));
  }

  if (violations.isEmpty) {
    if (!quiet) {
      stdout.writeln(
        'Architecture Guard: ${files.length} files checked, '
        'no violations found.',
      );
    }

    exit(0);
  }

  for (final violation in violations) {
    stdout.writeln(violation.format());
    stdout.writeln('${'-' * 72}\n');
  }

  stdout.writeln(
    'Architecture Guard: ${violations.length} violation(s) in '
    '${files.length} files checked.',
  );
  stdout.writeln(
    'Architecture violations are defects, not stylistic differences. '
    'See ARCHITECTURE.md.',
  );

  exit(1);
}

/// Walks up from the current directory looking for `pubspec.yaml`.
///
/// Lets the guard run from anywhere in the tree, which matters because a
/// pre-commit hook's working directory is not always the package root.
String? _findPackageRoot() {
  var directory = Directory.current;

  for (var depth = 0; depth < 8; depth++) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      return directory.path;
    }

    final parent = directory.parent;

    if (parent.path == directory.path) break;

    directory = parent;
  }

  return null;
}

/// Reads `name:` from pubspec.yaml, so `package:` self-imports resolve.
String _readPackageName(String packageRoot) {
  final pubspec = File('$packageRoot/pubspec.yaml').readAsLinesSync();

  for (final line in pubspec) {
    final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);

    if (match != null) return match.group(1)!;
  }

  return 'TajeerAi';
}
