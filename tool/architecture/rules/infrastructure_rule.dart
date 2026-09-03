import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Keeps infrastructure exception types out of the layers above.
///
/// Covers rules 27 and 28. Rule 27 is the one that makes the failure taxonomy
/// worth having: without it, a controller ends up catching `DioException`, and
/// swapping the HTTP client becomes a change to the UI.
class InfrastructureRule implements ArchitectureRule {
  const InfrastructureRule();

  @override
  String get id => 'RULE 27/28';

  @override
  String get description => 'Infrastructure exception containment';

  /// Files defining an infrastructure exception type.
  ///
  /// May be imported by `data/` -- translating them is exactly the data
  /// layer's job -- and by a feature's `realtime/`, which is the socket's
  /// adapter. Nowhere else.
  static const List<String> _exceptionFiles = <String>[
    'lib/infrastructure/network/http_exception.dart',
    'lib/infrastructure/realtime/socket_exception.dart',
  ];

  /// Third-party error types that must not surface above the data layer.
  static const Map<String, String> _forbiddenErrorPackages = <String, String>{
    'dio': 'DioException',
    'socket_io_client': 'socket transport errors',
    'drift': 'drift database exceptions',
  };

  @override
  List<Violation> check(ArchitectureContext context) {
    final file = context.file;

    final translatesErrors =
        file.layer == Layer.data ||
        file.layer == Layer.featureRealtime ||
        file.layer == Layer.infrastructure ||
        file.layer == Layer.app;

    if (translatesErrors) return const <Violation>[];

    final violations = <Violation>[];

    for (final import in context.imports) {
      final target = context.locationOf(import);

      if (target != null && _exceptionFiles.contains(target.path)) {
        violations.add(
          Violation(
            rule:
                'RULE 27 - Infrastructure exception types must not leak '
                'into Presentation or Domain.',
            source: file.path,
            forbiddenDependency: target.path,
            line: import.line,
            reason:
                'This layer would have to know which transport failed in '
                'order to react, so replacing that transport becomes a change '
                'here too.',
            allowedAlternative:
                'Catch the infrastructure exception in the data layer and '
                'rethrow it as an AppFailure from lib/failures/.',
          ),
        );
      }

      final package = import.packageName;

      if (package == null) continue;

      final label = _forbiddenErrorPackages[package];

      if (label != null &&
          (file.layer == Layer.domain ||
              file.layer == Layer.presentation ||
              file.layer == Layer.application)) {
        violations.add(
          Violation(
            rule:
                'RULE 27 - Infrastructure error types must not leak past '
                'the data layer.',
            source: file.path,
            forbiddenDependency: import.raw,
            line: import.line,
            reason:
                'Importing $package here exposes $label to a layer that must '
                'stay independent of the transport.',
            allowedAlternative:
                'Translate it to an AppFailure at the data boundary.',
          ),
        );
      }
    }

    return violations;
  }
}

/// Stops generated code being used to cross a boundary.
///
/// Rule 28. Generated files are checked like any other -- but a hand-written
/// file must not reach *through* generated output to import something it could
/// not import directly. In practice that means a `part` file inherits its
/// parent library's obligations, which this enforces by refusing to exempt
/// generated sources from the other rules.
class GeneratedCodeRule implements ArchitectureRule {
  const GeneratedCodeRule();

  @override
  String get id => 'RULE 28';

  @override
  String get description => 'Generated code is not an architecture bypass';

  @override
  List<Violation> check(ArchitectureContext context) {
    final file = context.file;

    if (!file.isGenerated) return const <Violation>[];

    final violations = <Violation>[];

    for (final import in context.imports) {
      final target = context.locationOf(import);

      if (target == null) continue;

      // A generated file in one feature importing another feature's internals
      // means the *source* file declared something that crosses the boundary.
      // Reported against the generated file, which points at the annotation
      // that caused it.
      final feature = file.feature;
      final targetFeature = target.feature;

      if (feature != null &&
          targetFeature != null &&
          feature != targetFeature &&
          !target.path.contains('/application/contracts/')) {
        violations.add(
          Violation(
            rule:
                'RULE 28 - Generated code must not be used to bypass '
                'architecture boundaries.',
            source: file.path,
            forbiddenDependency: target.path,
            line: import.line,
            reason:
                'Generated output crosses a feature boundary, which means the '
                'annotated source declares a type from another feature. The '
                'boundary is broken whether a human or a builder wrote the '
                'import.',
            allowedAlternative:
                'Change the annotated declaration to use a type from '
                'features/$targetFeature/application/contracts/.',
          ),
        );
      }
    }

    return violations;
  }
}
