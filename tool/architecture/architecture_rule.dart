import 'import_analyzer.dart';
import 'path_classifier.dart';

/// One architectural violation, in the reporting format the brief specifies.
class Violation {
  const Violation({
    required this.rule,
    required this.source,
    required this.forbiddenDependency,
    required this.reason,
    required this.allowedAlternative,
    this.line,
  });

  /// Rule number and description, e.g. "RULE 14 - Features must not ...".
  final String rule;

  final String source;
  final String forbiddenDependency;
  final String reason;
  final String allowedAlternative;
  final int? line;

  /// The report block. Written here rather than at the call site so every
  /// violation reads identically whichever rule produced it.
  String format() {
    final location = line == null ? source : '$source:$line';

    return '''
ARCHITECTURE VIOLATION

Rule:
$rule

Source:
$location

Forbidden dependency:
$forbiddenDependency

Reason:
$reason

Allowed alternative:
$allowedAlternative
''';
  }
}

/// What a rule is given to make its decision.
class ArchitectureContext {
  const ArchitectureContext({
    required this.file,
    required this.imports,
    required this.allFiles,
    this.source = '',
  });

  /// The file being checked.
  final FileLocation file;

  /// Its resolved imports.
  final List<ResolvedImport> imports;

  /// Every file in the project, for rules that reason about structure rather
  /// than about one file's imports (forbidden directories, for instance).
  final List<FileLocation> allFiles;

  /// The file's text, for the rules that read what a file does rather than
  /// what it imports (RULES 34 and 35). Empty when there is none to give.
  final String source;

  /// The classification of an imported project file, or null when the import
  /// is external or unresolvable.
  FileLocation? locationOf(ResolvedImport import) {
    final path = import.projectPath;

    if (path == null) return null;

    return PathClassifier.classify(path);
  }
}

/// A single architectural rule.
///
/// Rules are objects rather than branches in one long function so that adding
/// one is adding a file: implement this, register it in the list, done. That
/// is what "easy to extend" has to mean for a checker that will outlive the
/// engineer who wrote it.
abstract interface class ArchitectureRule {
  /// Human-readable identity, e.g. "RULE 6".
  String get id;

  String get description;

  /// Violations found in [context]. Empty when the file is compliant.
  List<Violation> check(ArchitectureContext context);
}

/// Rules that inspect the project as a whole rather than one file at a time.
abstract interface class ProjectRule {
  String get id;

  String get description;

  List<Violation> checkProject(List<FileLocation> files);
}
