import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Enforces the dependency direction between layers.
///
/// Covers rules 1, 2, 6, 7, 8, 9, 10, 11 and 25. One rule object rather than
/// nine because they are all the same question -- "may layer A import layer
/// B?" -- and expressing that as a single table is what keeps the answers
/// consistent. Each entry still reports its own rule number, so a violation
/// message is as specific as if each had its own class.
class LayerDependencyRule implements ArchitectureRule {
  const LayerDependencyRule();

  @override
  String get id => 'RULE 1/2/6-11/25';

  @override
  String get description => 'Layer dependency direction';

  /// Packages the domain layer may never see.
  ///
  /// The domain is the business, expressed in plain Dart. The moment it
  /// imports Flutter it can no longer be tested without a widget binding, and
  /// the moment it imports Dio or drift the business rules are welded to a
  /// transport that will be replaced before they are.
  static const Map<String, String> forbiddenInDomain = <String, String>{
    'flutter': 'Flutter',
    'flutter_riverpod': 'Riverpod',
    'riverpod': 'Riverpod',
    'riverpod_annotation': 'Riverpod',
    'hooks_riverpod': 'Riverpod',
    'dio': 'the HTTP client',
    'drift': 'the database engine',
    'sqlite3': 'SQLite',
    'socket_io_client': 'the WebSocket client',
    'shared_preferences': 'device storage',
    'flutter_secure_storage': 'device storage',
    'path_provider': 'device APIs',
    'connectivity_plus': 'device APIs',
    'go_router': 'the router',
  };

  /// Packages the application layer may never see.
  ///
  /// Looser than the domain -- an application coordinator legitimately talks
  /// to infrastructure abstractions -- but still no UI. A coordinator that
  /// imports Flutter has started making presentation decisions.
  static const Map<String, String> forbiddenInApplication = <String, String>{
    'flutter': 'Flutter',
    'go_router': 'the router',
  };

  @override
  List<Violation> check(ArchitectureContext context) {
    final violations = <Violation>[];
    final file = context.file;

    for (final import in context.imports) {
      // ---- External package rules -------------------------------------
      final package = import.packageName;

      if (package != null) {
        if (file.layer == Layer.domain) {
          final label = forbiddenInDomain[package];

          if (label != null) {
            violations.add(
              Violation(
                rule:
                    'RULE 6/7/8/9/25 - The domain layer must remain '
                    'framework-independent.',
                source: file.path,
                forbiddenDependency: import.raw,
                line: import.line,
                reason:
                    'Domain code imports $label. Business rules must be '
                    'testable and portable without a UI framework, an HTTP '
                    'client, a database engine or device APIs.',
                allowedAlternative:
                    'Express the need as an interface in domain/repositories/ '
                    'and implement it in the feature data layer, which is '
                    'allowed to depend on infrastructure.',
              ),
            );
          }
        }

        if (file.layer == Layer.application) {
          final label = forbiddenInApplication[package];

          if (label != null) {
            violations.add(
              Violation(
                rule:
                    'RULE 10 - The application layer must not depend on '
                    'presentation concerns.',
                source: file.path,
                forbiddenDependency: import.raw,
                line: import.line,
                reason:
                    'Application code imports $label, which belongs to the '
                    'presentation layer. Coordinators orchestrate workflows '
                    'and must stay renderable-free so they can be tested '
                    'without a widget tree.',
                allowedAlternative:
                    'Publish an application event or expose state, and let a '
                    'presentation controller react to it.',
              ),
            );
          }
        }

        continue;
      }

      // ---- Project-internal rules -------------------------------------
      final target = context.locationOf(import);

      if (target == null) continue;

      violations.addAll(
        _checkProjectImport(file, target, import.raw, import.line),
      );
    }

    return violations;
  }

  List<Violation> _checkProjectImport(
    FileLocation file,
    FileLocation target,
    String raw,
    int line,
  ) {
    final violations = <Violation>[];

    switch (file.layer) {
      case Layer.presentation:
        // RULE 1 -- presentation must not import data.
        if (target.layer == Layer.data) {
          violations.add(
            Violation(
              rule: 'RULE 1 - Presentation must not import Data.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'A screen or controller reaching into the data layer binds '
                  'the UI to how data is stored and fetched, so a change to '
                  'persistence becomes a change to the UI.',
              allowedAlternative:
                  'Depend on a domain service or a domain repository '
                  'interface, resolved through a provider.',
            ),
          );
        }

        // RULE 2 -- presentation must not import infrastructure.
        //
        // `app/bootstrap/dependencies.dart` is the composition root and is
        // classified as `app`, so reading a provider from it is not an
        // infrastructure import and is not caught here.
        if (target.layer == Layer.infrastructure) {
          violations.add(
            Violation(
              rule:
                  'RULE 2/4/5/17 - Presentation must not import '
                  'Infrastructure.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'Presentation is reaching a socket, database or HTTP client '
                  'directly. The UI must react to persisted application '
                  'state, never drive a transport.',
              allowedAlternative:
                  'Go through a controller, then a domain service or an '
                  'application coordinator. Infrastructure is wired in '
                  'app/bootstrap/dependencies.dart.',
            ),
          );
        }

        // RULE 26 -- feature realtime payload types must not reach the UI.
        if (target.layer == Layer.featureRealtime &&
            PathClassifier.isWidgetOrScreen(file.path)) {
          violations.add(
            Violation(
              rule:
                  'RULE 26 - Raw realtime payload types must not leak into '
                  'presentation.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'A widget importing realtime event types couples the UI to '
                  'the wire format. Widgets must render domain entities read '
                  'from local state.',
              allowedAlternative:
                  'Let the socket handler persist the event and have the '
                  'widget watch the database through a controller.',
            ),
          );
        }

      case Layer.domain:
        // RULE 8/9 -- domain must not import infrastructure or UI.
        if (target.layer == Layer.infrastructure ||
            target.layer == Layer.designSystem ||
            target.layer == Layer.app ||
            target.layer == Layer.presentation ||
            target.layer == Layer.data ||
            target.layer == Layer.featureRealtime ||
            target.layer == Layer.application) {
          violations.add(
            Violation(
              rule:
                  'RULE 8/9/25 - Domain must not import Infrastructure, '
                  'Data, Application, UI or app wiring.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'The domain is the innermost layer. Anything it imports '
                  'becomes part of the business model\'s dependency surface, '
                  'and the rules stop being testable in isolation.',
              allowedAlternative:
                  'Define what the domain needs as an interface inside '
                  'domain/repositories/ and let an outer layer implement it.',
            ),
          );
        }

      case Layer.application:
        // RULE 10 -- application must not import presentation.
        if (target.layer == Layer.presentation) {
          violations.add(
            Violation(
              rule: 'RULE 10 - Application must not import Presentation.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'Workflow orchestration must not depend on the screens that '
                  'happen to trigger it, or the workflow can only ever run '
                  'from that UI.',
              allowedAlternative:
                  'Publish an application event; let the controller listen.',
            ),
          );
        }

      case Layer.infrastructure:
        // RULE 11 -- infrastructure must not import presentation.
        if (target.layer == Layer.presentation ||
            target.layer == Layer.designSystem) {
          violations.add(
            Violation(
              rule: 'RULE 11 - Infrastructure must not import Presentation.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'Infrastructure is business- and UI-agnostic. Importing a '
                  'screen or a widget inverts the dependency direction.',
              allowedAlternative:
                  'Expose a stream or a callback the presentation layer '
                  'subscribes to.',
            ),
          );
        }

        // RULE 12 -- infrastructure must not import feature business code.
        //
        // The single documented exception is the database, which must know
        // its own tables to generate a schema; see ARCHITECTURE.md.
        if (target.isFeatureFile && !_isDatabaseSchemaImport(file, target)) {
          violations.add(
            Violation(
              rule:
                  'RULE 12 - Infrastructure must not import feature '
                  'implementation.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'Infrastructure providing a technical capability must not '
                  'know which business feature uses it, or it cannot be '
                  'reused by the next one.',
              allowedAlternative:
                  'Keep the capability generic and let the feature adapt it, '
                  'as features/<name>/realtime/ does for the socket.',
            ),
          );
        }

      case Layer.designSystem:
        // RULE 18/23 -- the design system must stay business-agnostic.
        if (target.isFeatureFile) {
          violations.add(
            Violation(
              rule:
                  'RULE 18 - Design System components must remain '
                  'business-agnostic.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'A shared component importing a feature can no longer be '
                  'used by any other feature, which defeats the point of a '
                  'design system.',
              allowedAlternative:
                  'Accept what the component needs as parameters, and keep '
                  'the business-aware widget inside the feature.',
            ),
          );
        }

      case Layer.failures:
        // The failure taxonomy is the one thing every layer may import, so it
        // must itself import nothing. Enforced by ForbiddenDirectoryRule.
        break;

      case Layer.app:
      case Layer.data:
      case Layer.featureRealtime:
      case Layer.featureRoot:
      case Layer.other:
        break;
    }

    return violations;
  }

  /// The documented exception to rule 12.
  ///
  /// `AppDatabase` must import each feature's table definitions, because
  /// drift generates one schema for one database and the tables have to be
  /// declared on it. The alternative -- moving every feature's tables into
  /// infrastructure -- would be a worse violation: it would put business
  /// schema in a business-agnostic layer.
  ///
  /// Narrowed to exactly that file importing exactly a table declaration, so
  /// it cannot be used as a general escape hatch.
  static bool _isDatabaseSchemaImport(FileLocation file, FileLocation target) {
    final isDatabaseFile =
        file.path == 'lib/infrastructure/database/app_database.dart';
    final isSchemaFile =
        target.path.contains('/data/local/') &&
        (target.path.endsWith('_tables.dart') ||
            target.path.endsWith('_dao.dart'));

    return isDatabaseFile && isSchemaFile;
  }
}
