import '../architecture_rule.dart';
import '../import_analyzer.dart';
import '../path_classifier.dart';

/// The barrel a feature is allowed to import.
const String _barrel = 'lib/design_system/design_system.dart';

/// The only part of `app/` a design-system file may reach.
const String _themeDirectory = 'lib/app/theme/';

/// Packages a design system must not be coupled to.
///
/// Not an arbitrary blocklist: each of these makes the design system depend on
/// a decision that belongs to the application. A component that reads a
/// provider cannot be used by a screen that stores its state differently; one
/// that imports a router decides how navigation works for everybody; one that
/// imports Dio or drift has stopped being a design system altogether.
const Map<String, String> _forbiddenPackages = <String, String>{
  'flutter_riverpod':
      'take the value as a parameter and the change as a callback',
  'riverpod': 'take the value as a parameter and the change as a callback',
  'riverpod_annotation':
      'take the value as a parameter and the change as a callback',
  'go_router': 'accept an onTap callback; the screen decides where it goes',
  'dio': 'accept the data; the feature fetches it',
  'drift': 'accept the data; the feature reads it',
  'socket_io_client': 'accept the data; the feature subscribes',
  'flutter_secure_storage': 'accept the value; the feature stores it',
  'shared_preferences': 'accept the value; the feature stores it',
};

/// RULE 31 — a feature reaches the design system only through its barrel.
///
/// Two reasons, and the second is the one people are surprised by. The barrel
/// is the reviewable statement of what the system offers, and a screen holding
/// a dozen `../../../../design_system/...` lines is unreadable. But it also
/// keeps the coverage gate honest in the other direction: a *test* that
/// imported the barrel would load every component library at once and file a
/// coverage record for each, so the number would describe how the test spelled
/// its imports rather than what it exercised. Hence the asymmetry — features
/// use the barrel, tests use leaves, and design-system files use neither.
class DesignSystemBarrelRule implements ArchitectureRule {
  const DesignSystemBarrelRule();

  @override
  String get id => 'RULE 31';

  @override
  String get description =>
      'Features must import the Design System through design_system.dart.';

  @override
  List<Violation> check(ArchitectureContext context) {
    if (!context.file.isFeatureFile) {
      return const <Violation>[];
    }

    final List<Violation> violations = <Violation>[];

    for (final ResolvedImport import in context.imports) {
      final String? path = import.projectPath;
      if (path == null ||
          !path.startsWith('lib/design_system/') ||
          path == _barrel) {
        continue;
      }

      violations.add(
        Violation(
          rule: '$id - $description',
          source: context.file.path,
          forbiddenDependency: import.raw,
          line: import.line,
          reason:
              'Reaching past the barrel into a component file couples the '
              'feature to where that component happens to live today, and '
              'hides from review what the feature actually consumes.',
          allowedAlternative:
              "import '.../design_system/design_system.dart'; and use the "
              'component from there.',
        ),
      );
    }

    return violations;
  }
}

/// RULE 32 — the design system may reach `app/theme/`, and nothing else in
/// `app/`.
///
/// RULE 18 only ever checked that a design-system file did not import a
/// *feature*, which left `app/bootstrap/dependencies.dart` and the router
/// wide open. A component that reads the dependency graph is not reusable; it
/// is a screen with a component's name.
class DesignSystemAppAccessRule implements ArchitectureRule {
  const DesignSystemAppAccessRule();

  @override
  String get id => 'RULE 32';

  @override
  String get description =>
      'The Design System may import app/theme/ only, never the rest of app/.';

  @override
  List<Violation> check(ArchitectureContext context) {
    if (context.file.layer != Layer.designSystem) {
      return const <Violation>[];
    }

    final List<Violation> violations = <Violation>[];

    for (final ResolvedImport import in context.imports) {
      final String? path = import.projectPath;
      if (path == null ||
          !path.startsWith('lib/app/') ||
          path.startsWith(_themeDirectory)) {
        continue;
      }

      violations.add(
        Violation(
          rule: '$id - $description',
          source: context.file.path,
          forbiddenDependency: import.raw,
          line: import.line,
          reason:
              'Everything under app/ outside theme/ is composition: the '
              'dependency graph, the router, the locale. A component that '
              'reads any of it can only be used by an app wired exactly like '
              'this one.',
          allowedAlternative:
              'Accept what the component needs as a parameter, and report what '
              'happened through a callback.',
        ),
      );
    }

    return violations;
  }
}

/// RULE 33 — the design system stays free of the application's plumbing.
class DesignSystemPackageRule implements ArchitectureRule {
  const DesignSystemPackageRule();

  @override
  String get id => 'RULE 33';

  @override
  String get description =>
      'The Design System must not depend on state management, routing, '
      'networking or storage packages.';

  @override
  List<Violation> check(ArchitectureContext context) {
    if (context.file.layer != Layer.designSystem) {
      return const <Violation>[];
    }

    final List<Violation> violations = <Violation>[];

    for (final ResolvedImport import in context.imports) {
      final String? package = import.packageName;
      final String? alternative = package == null
          ? null
          : _forbiddenPackages[package];
      if (alternative == null) {
        continue;
      }

      violations.add(
        Violation(
          rule: '$id - $description',
          source: context.file.path,
          forbiddenDependency: import.raw,
          line: import.line,
          reason:
              'A design system coupled to $package is only usable by an '
              'application that made the same choice.',
          allowedAlternative: alternative,
        ),
      );
    }

    return violations;
  }
}
