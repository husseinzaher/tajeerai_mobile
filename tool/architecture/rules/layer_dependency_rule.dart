import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Enforces the dependency direction between layers.
///
/// Covers rules 1, 2, 6, 7, 8, 9, 10, 11, 12, 25, 37 and 38. One rule object
/// rather than twelve because they are all the same question -- "may layer A
/// import layer B?" -- and expressing that as a single table is what keeps
/// the answers consistent. Each entry still reports its own rule number, so a
/// violation message is as specific as if each had its own class.
class LayerDependencyRule implements ArchitectureRule {
  const LayerDependencyRule();

  @override
  String get id => 'RULE 1/2/6-12/25/37/38';

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
  /// to the shared engines in `infrastructure/` -- but still no UI. A
  /// coordinator that imports Flutter has started making presentation
  /// decisions.
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
                    'and implement it in infrastructure/adapters/<feature>/, '
                    'which is allowed to depend on the engines.',
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
        // RULE 1 -- presentation must not import an adapter.
        if (target.layer == Layer.adapter) {
          violations.add(
            Violation(
              rule:
                  'RULE 1 - Presentation must not import an infrastructure '
                  'adapter.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'A screen or controller reaching into an adapter binds the '
                  'UI to how data is stored, fetched and decoded, so a change '
                  'to persistence or to the wire format becomes a change to '
                  'the UI.',
              allowedAlternative:
                  'Depend on a domain service, a domain repository interface '
                  'or an application port, resolved through a provider.',
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
                  'Presentation is reaching a socket, database, HTTP client '
                  'or device API directly. The UI must react to persisted '
                  'application state, never drive a transport.',
              allowedAlternative:
                  'Go through a controller, then a domain service or an '
                  'application coordinator. Infrastructure is wired in '
                  'app/bootstrap/dependencies.dart.',
            ),
          );
        }

      case Layer.domain:
        // RULE 8/9 -- domain must not import infrastructure or UI.
        if (target.layer == Layer.infrastructure ||
            target.layer == Layer.adapter ||
            target.layer == Layer.designSystem ||
            target.layer == Layer.app ||
            target.layer == Layer.presentation ||
            target.layer == Layer.application) {
          violations.add(
            Violation(
              rule:
                  'RULE 8/9/25 - Domain must not import Infrastructure, '
                  'Adapters, Application, UI or app wiring.',
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

        // RULE 37 -- application depends on ports, never on their
        // implementations.
        if (target.layer == Layer.adapter) {
          violations.add(
            Violation(
              rule:
                  'RULE 37 - Application must not import an infrastructure '
                  'adapter.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'A coordinator that names a repository implementation, a '
                  'remote data source or a DTO can only be tested against '
                  'that implementation, and the port it should depend on '
                  'stops being the boundary.',
              allowedAlternative:
                  'Depend on the domain repository interface or on a port in '
                  'application/ports/, and let app/bootstrap/dependencies.dart '
                  'supply the adapter.',
            ),
          );
        }

      case Layer.infrastructure:
      case Layer.adapter:
        // RULE 11 -- infrastructure must not import presentation, the design
        // system, or the app's composition.
        if (target.layer == Layer.presentation ||
            target.layer == Layer.designSystem ||
            target.layer == Layer.app) {
          violations.add(
            Violation(
              rule:
                  'RULE 11 - Infrastructure must not import Presentation, '
                  'the Design System or app/.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'Infrastructure is business- and UI-agnostic, and it is '
                  'told what it needs by the composition root. Importing a '
                  'screen, a widget or the app\'s configuration inverts the '
                  'dependency direction.',
              allowedAlternative:
                  'Take the value as a constructor parameter and let '
                  'app/bootstrap/dependencies.dart supply it; expose a stream '
                  'or a callback for anything the UI must react to.',
            ),
          );
        }

        if (file.layer == Layer.infrastructure) {
          // RULE 12 -- shared infrastructure knows no feature and no adapter.
          //
          // The single documented exception is the database, which must know
          // its own tables to generate a schema; see ARCHITECTURE.md.
          if ((target.isFeatureFile || target.layer == Layer.adapter) &&
              !_isDatabaseSchemaImport(file, target)) {
            violations.add(
              Violation(
                rule:
                    'RULE 12 - Shared infrastructure must not import a '
                    'feature or an adapter.',
                source: file.path,
                forbiddenDependency: target.path,
                line: line,
                reason:
                    'A shared engine that knows which business feature uses '
                    'it, or how, cannot be reused by the next one.',
                allowedAlternative:
                    'Keep the engine generic and let the feature adapt it in '
                    'infrastructure/adapters/<feature>/, as the conversation '
                    'socket handler does for the socket.',
              ),
            );
          }
        } else if (target.isFeatureFile &&
            target.layer != Layer.adapter &&
            target.feature == file.feature &&
            target.layer != Layer.domain &&
            !PathClassifier.isApplicationBoundary(target.path)) {
          // RULE 38 -- an adapter sees its feature's domain and the parts of
          // its application layer that face outward: ports, contracts and
          // events. Never its coordinators, its state or its presentation.
          violations.add(
            Violation(
              rule:
                  'RULE 38 - An adapter may import its feature\'s domain, '
                  'ports, contracts and events only.',
              source: file.path,
              forbiddenDependency: target.path,
              line: line,
              reason:
                  'An adapter implements what the feature asked for. One that '
                  'imports a coordinator, shared state or a screen has the '
                  'dependency pointing the wrong way, and the feature can no '
                  'longer be tested with the adapter swapped out.',
              allowedAlternative:
                  'Implement the port or the domain repository interface, and '
                  'announce anything the feature must react to through an '
                  'event in application/events/.',
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
      case Layer.featureRoot:
      case Layer.other:
        break;
    }

    return violations;
  }

  /// The documented exception to rule 12.
  ///
  /// `AppDatabase` must import each feature's table and DAO declarations,
  /// because drift generates one schema for one database and the tables have
  /// to be declared on it. The alternative -- moving every feature's tables
  /// into the shared engine -- would be the worse violation: it would put
  /// business schema in a business-agnostic layer.
  ///
  /// Narrowed to exactly that file importing exactly a table or DAO
  /// declaration from an adapter's `local/`, so it cannot be used as a general
  /// escape hatch.
  static bool _isDatabaseSchemaImport(FileLocation file, FileLocation target) {
    final isDatabaseFile =
        file.path == 'lib/infrastructure/storage/database/app_database.dart';
    final isSchemaFile =
        target.layer == Layer.adapter &&
        target.path.contains('/local/') &&
        (target.path.endsWith('_tables.dart') ||
            target.path.endsWith('_dao.dart'));

    return isDatabaseFile && isSchemaFile;
  }
}
