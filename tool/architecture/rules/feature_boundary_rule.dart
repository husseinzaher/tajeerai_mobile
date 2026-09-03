import '../architecture_rule.dart';
import '../path_classifier.dart';

/// Enforces feature isolation.
///
/// Covers rules 13, 14, 15 and 30. A feature may only reach another feature
/// through an explicit application contract; everything else is coupling that
/// makes the two impossible to change separately.
///
/// Rule 30 falls out of how this is written: nothing here enumerates the
/// features that exist, so a feature added next year is checked by the same
/// code with no edit.
class FeatureBoundaryRule implements ArchitectureRule {
  const FeatureBoundaryRule();

  @override
  String get id => 'RULE 13/14/15/30';

  @override
  String get description => 'Feature boundaries';

  /// The one directory of a feature another feature may import.
  ///
  /// `application/contracts/` holds interfaces that state *what* a feature
  /// offers, without exposing how. Everything else -- entities, services,
  /// repositories, data, realtime, screens -- is internal.
  static const String contractsSegment = '/application/contracts/';

  @override
  List<Violation> check(ArchitectureContext context) {
    final file = context.file;
    final feature = file.feature;

    if (feature == null) return const <Violation>[];

    final violations = <Violation>[];

    for (final import in context.imports) {
      final target = context.locationOf(import);

      if (target == null) continue;

      final targetFeature = target.feature;

      // Same feature, or not a feature at all -- not this rule's business.
      if (targetFeature == null || targetFeature == feature) continue;

      // The sanctioned door.
      if (target.path.contains(contractsSegment)) continue;

      violations.add(
        Violation(
          rule: _ruleFor(target),
          source: file.path,
          forbiddenDependency: target.path,
          line: import.line,
          reason:
              'The $feature feature depends directly on $targetFeature\'s '
              '${_layerName(target.layer)}. The two can no longer be changed, '
              'tested or removed independently.',
          allowedAlternative:
              'Define what $feature needs as an interface in '
              'features/$targetFeature/application/contracts/, implement it '
              'in $targetFeature, and wire it in '
              'app/bootstrap/dependencies.dart. See SessionCapability for the '
              'worked example.',
        ),
      );
    }

    return violations;
  }

  static String _ruleFor(FileLocation target) {
    return switch (target.layer) {
      Layer.presentation =>
        'RULE 13 - Feature A must not import Feature B presentation.',
      Layer.data =>
        'RULE 14 - Feature A must not import Feature B data implementation.',
      Layer.featureRealtime =>
        'RULE 15 - Feature A must not import Feature B realtime internals.',
      _ =>
        'RULE 13/14/15 - Features must communicate through explicit '
            'application contracts.',
    };
  }

  static String _layerName(Layer layer) => switch (layer) {
    Layer.presentation => 'presentation layer',
    Layer.application => 'application internals',
    Layer.domain => 'domain layer',
    Layer.data => 'data layer',
    Layer.featureRealtime => 'realtime layer',
    _ => 'internals',
  };
}
