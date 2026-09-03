import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Bans dumping-ground directories, and keeps the failure kernel pure.
///
/// Covers rules 19-23 and the purity constraint that makes `lib/failures/`
/// legitimate rather than `shared/` with a nicer name.
class ForbiddenDirectoryRule implements ProjectRule {
  const ForbiddenDirectoryRule();

  @override
  String get id => 'RULE 19/20/21/22/23';

  @override
  String get description => 'Forbidden directories';

  /// Directory names that may not appear anywhere under `lib/`, and why.
  ///
  /// Each of these attracts code that belongs somewhere specific. A `utils/`
  /// folder is where a business rule goes to hide from review.
  static const Map<String, String> _forbidden = <String, String>{
    'core':
        'A root core/ directory becomes an unowned layer that every '
        'feature depends on and nobody maintains.',
    'shared':
        'A shared/ directory has no architectural responsibility; what '
        'goes in it is decided by convenience.',
    'helpers':
        'A helpers/ directory names how code is used, not what it is '
        'responsible for.',
    'utils':
        'A utils/ directory accumulates business rules that should live '
        'in a domain service.',
    'misc': 'A misc/ directory is an admission that the code has no home.',
    'common': 'A common/ directory is shared/ under another name.',
  };

  /// Packages `lib/failures/` may import.
  ///
  /// Only `dart:` libraries. The taxonomy is importable by every layer
  /// including the framework-free domain, which is only safe while it depends
  /// on nothing -- the moment it imports Flutter it drags Flutter into the
  /// domain, and it stops being a kernel and becomes the `shared/` directory
  /// rule 20 forbids.
  static const Set<String> _failuresAllowedPackages = <String>{};

  @override
  List<Violation> checkProject(List<FileLocation> files) {
    final violations = <Violation>[];
    final reported = <String>{};

    for (final file in files) {
      if (!file.path.startsWith('lib/')) continue;

      final segments = file.path.split('/');

      for (var index = 1; index < segments.length - 1; index++) {
        final segment = segments[index];
        final reason = _forbidden[segment];

        if (reason == null) continue;

        // A generic `providers/` folder is only forbidden inside a feature's
        // presentation layer -- rule 21 is about not turning Riverpod into an
        // architectural layer, not about the word itself.
        final directory = segments.sublist(0, index + 1).join('/');

        if (!reported.add(directory)) continue;

        violations.add(
          Violation(
            rule:
                '${_ruleNumberFor(segment)} - The $segment/ directory is '
                'forbidden.',
            source: directory,
            forbiddenDependency: '$directory/',
            reason: reason,
            allowedAlternative:
                'Move each file to the layer that owns its responsibility: a '
                'business rule to domain/services/, orchestration to '
                'application/coordinators/, a technical capability to '
                'infrastructure/, a reusable widget to design_system/.',
          ),
        );
      }

      // RULE 21 -- no generic providers/ folder in presentation.
      if (file.path.contains('/presentation/providers/')) {
        final directory = file.path.substring(
          0,
          file.path.indexOf('/presentation/providers/') +
              '/presentation/providers'.length,
        );

        if (reported.add(directory)) {
          violations.add(
            Violation(
              rule:
                  'RULE 21 - Generic presentation/providers/ folders are '
                  'forbidden.',
              source: directory,
              forbiddenDependency: '$directory/',
              reason:
                  'Riverpod is an implementation mechanism, not an '
                  'architectural layer. A folder named after it collects '
                  'unrelated state and hides which screen owns what.',
              allowedAlternative:
                  'Declare each provider beside the controller that owns it, '
                  'in presentation/controllers/.',
            ),
          );
        }
      }
    }

    return violations;
  }

  /// The purity check on `lib/failures/`.
  ///
  /// Separate from [checkProject] because it inspects imports, not structure.
  List<Violation> checkFailuresPurity(ArchitectureContext context) {
    if (context.file.layer != Layer.failures) return const <Violation>[];

    final violations = <Violation>[];

    for (final import in context.imports) {
      final package = import.packageName;

      if (package == null) {
        final target = context.locationOf(import);

        // Imports within failures/ are fine; anything else is not.
        if (target == null || target.layer == Layer.failures) continue;

        violations.add(
          Violation(
            rule: 'RULE 20/24 - The failure taxonomy must depend on nothing.',
            source: context.file.path,
            forbiddenDependency: target.path,
            line: import.line,
            reason:
                'lib/failures/ is importable by every layer, including the '
                'framework-free domain. Anything it imports is transitively '
                'imported by the domain, which is how a permitted kernel '
                'turns into the shared/ dumping ground rule 20 forbids.',
            allowedAlternative:
                'Keep the taxonomy dependency-free. Map infrastructure errors '
                'onto it at the data-layer boundary instead.',
          ),
        );

        continue;
      }

      if (_failuresAllowedPackages.contains(package)) continue;

      violations.add(
        Violation(
          rule: 'RULE 20/24 - The failure taxonomy must depend on nothing.',
          source: context.file.path,
          forbiddenDependency: import.raw,
          line: import.line,
          reason:
              'lib/failures/ imports a third-party package. Because every '
              'layer may import it, that dependency reaches the domain layer '
              'too.',
          allowedAlternative:
              'Express the failure in plain Dart and translate the '
              'package-specific error where it is caught.',
        ),
      );
    }

    return violations;
  }

  static String _ruleNumberFor(String segment) => switch (segment) {
    'core' => 'RULE 19',
    'shared' => 'RULE 20',
    'helpers' => 'RULE 22',
    'utils' => 'RULE 23',
    _ => 'RULE 20',
  };
}
