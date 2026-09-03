import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Enforces what UI code specifically may touch.
///
/// Covers rules 3, 4, 5, 16, 17 and 18. Distinct from
/// [LayerDependencyRule] because these are about *widgets and screens*, not
/// about the presentation layer as a whole: a controller may hold a service
/// reference that a widget may not, and collapsing the two would either let
/// widgets do too much or stop controllers doing their job.
class PresentationAccessRule implements ArchitectureRule {
  const PresentationAccessRule();

  @override
  String get id => 'RULE 3/4/5/16/17/18';

  @override
  String get description => 'Presentation access restrictions';

  /// Packages no widget, screen or controller may import directly.
  ///
  /// Every one of these is a transport or an engine. A widget that imports
  /// `drift` is a widget that can write to the database, and the offline-first
  /// read path stops being the only way state changes.
  static const Map<String, String> _forbiddenPackages = <String, String>{
    'drift': 'the database engine',
    'sqlite3': 'SQLite',
    'drift_flutter': 'the database engine',
    'socket_io_client': 'the WebSocket client',
    'dio': 'the HTTP client',
    'flutter_secure_storage': 'secure storage',
  };

  /// Filename fragments that mark a repository implementation.
  static const List<String> _implementationMarkers = <String>[
    '_repository_impl.dart',
    '_data_source.dart',
    '_dao.dart',
  ];

  @override
  List<Violation> check(ArchitectureContext context) {
    final file = context.file;

    if (file.layer != Layer.presentation) return const <Violation>[];

    final violations = <Violation>[];
    final isWidget = PathClassifier.isWidgetOrScreen(file.path);

    for (final import in context.imports) {
      final package = import.packageName;

      if (package != null) {
        final label = _forbiddenPackages[package];

        if (label != null) {
          violations.add(
            Violation(
              rule:
                  'RULE 4/5/16/17 - Presentation must not use $label '
                  'directly.',
              source: file.path,
              forbiddenDependency: import.raw,
              line: import.line,
              reason:
                  'UI code importing $label can bypass the architecture '
                  'entirely: it could read or write outside the '
                  'controller -> service -> repository path, so the state on '
                  'screen would no longer be the state in local storage.',
              allowedAlternative:
                  'Read state through a controller that watches a domain '
                  'service; perform writes through the service, which goes '
                  'through the repository and the outbox.',
            ),
          );
        }

        continue;
      }

      final target = context.locationOf(import);

      if (target == null) continue;

      // RULE 3/18 -- no repository or data-source implementations.
      if (_isImplementation(target.path)) {
        violations.add(
          Violation(
            rule:
                'RULE 3/18 - Presentation must not import repository or '
                'data-source implementations.',
            source: file.path,
            forbiddenDependency: target.path,
            line: import.line,
            reason:
                'Depending on a concrete implementation ties the screen to '
                'one storage and transport choice, and makes the controller '
                'untestable without them.',
            allowedAlternative:
                'Depend on the domain interface (domain/repositories/) or a '
                'domain service, resolved through a provider.',
          ),
        );
      }

      // RULE 18 -- a screen must not reach a repository at all, even the
      // interface: a screen's dependency is a controller.
      if (isWidget &&
          target.layer == Layer.domain &&
          target.path.contains('/domain/repositories/')) {
        violations.add(
          Violation(
            rule: 'RULE 18 - Screens must not import repositories directly.',
            source: file.path,
            forbiddenDependency: target.path,
            line: import.line,
            reason:
                'A widget holding a repository performs data access from the '
                'build tree, where it cannot be sequenced, retried or tested.',
            allowedAlternative:
                'Move the call into a controller in '
                'presentation/controllers/ and have the widget watch it.',
          ),
        );
      }
    }

    return violations;
  }

  static bool _isImplementation(String path) =>
      _implementationMarkers.any(path.endsWith);
}
