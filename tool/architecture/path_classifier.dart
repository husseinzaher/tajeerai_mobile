/// Where a file sits in the architecture.
///
/// Every rule is expressed in terms of these, not in terms of path substrings,
/// so a rule reads as "presentation must not import an adapter" rather than as
/// a string comparison nobody can audit.
enum Layer {
  /// `app/` -- bootstrap, routing, config, theme, localization.
  app,

  /// `design_system/` -- business-agnostic UI.
  designSystem,

  /// `infrastructure/` outside `adapters/` -- the shared technical engines:
  /// HTTP, the socket, the database, storage, device, logging.
  infrastructure,

  /// `infrastructure/adapters/<feature>/` -- one feature's implementations of
  /// its domain contracts and application ports over those engines.
  adapter,

  /// `failures/` -- the framework-free failure taxonomy every layer may use.
  failures,

  /// `features/<name>/presentation/`
  presentation,

  /// `features/<name>/application/`
  application,

  /// `features/<name>/domain/`
  domain,

  /// A file under `features/<name>/` in none of the three layers. A feature
  /// is exactly presentation, application and domain, so this is a violation
  /// rather than a classification -- see `ForbiddenDirectoryRule`.
  featureRoot,

  /// Anything else -- `main.dart`, tests, tooling.
  other,
}

/// One classified Dart file.
class FileLocation {
  const FileLocation({
    required this.path,
    required this.layer,
    this.feature,
    this.isGenerated = false,
  });

  /// Path relative to the package root, always with forward slashes.
  final String path;

  final Layer layer;

  /// The owning feature, for anything under `features/` and for an adapter
  /// under `infrastructure/adapters/`.
  ///
  /// Set for adapters on purpose: the feature-boundary rules read it, so an
  /// adapter is held to the same boundary as the feature it serves -- it may
  /// reach another feature only through that feature's published contracts.
  final String? feature;

  /// True for `.g.dart` / `.freezed.dart` output.
  ///
  /// Generated files are classified like any other -- they are still subject
  /// to the boundaries (rule 28) -- but a rule may consult this to avoid
  /// failing on an import a generator is entitled to emit.
  final bool isGenerated;

  bool get isFeatureFile => feature != null;

  @override
  String toString() => path;
}

/// Turns a path into a [FileLocation].
///
/// Deliberately the *only* place path shapes are interpreted. A rule that
/// invented its own path parsing would drift from this one, and the two would
/// disagree about which layer a file is in -- which is how an architecture
/// checker starts producing false positives nobody trusts.
abstract final class PathClassifier {
  static const String _libPrefix = 'lib/';

  /// The directory under `infrastructure/` that holds feature adapters.
  static const String adaptersSegment = 'adapters';

  static FileLocation classify(String rawPath) {
    final path = rawPath.replaceAll(r'\', '/');
    final isGenerated =
        path.endsWith('.g.dart') || path.endsWith('.freezed.dart');

    if (!path.startsWith(_libPrefix)) {
      return FileLocation(
        path: path,
        layer: Layer.other,
        isGenerated: isGenerated,
      );
    }

    final segments = path.substring(_libPrefix.length).split('/');

    if (segments.isEmpty) {
      return FileLocation(
        path: path,
        layer: Layer.other,
        isGenerated: isGenerated,
      );
    }

    switch (segments.first) {
      case 'app':
        return FileLocation(
          path: path,
          layer: Layer.app,
          isGenerated: isGenerated,
        );
      case 'design_system':
        return FileLocation(
          path: path,
          layer: Layer.designSystem,
          isGenerated: isGenerated,
        );
      case 'infrastructure':
        return _classifyInfrastructure(path, segments, isGenerated);
      case 'failures':
        return FileLocation(
          path: path,
          layer: Layer.failures,
          isGenerated: isGenerated,
        );
      case 'features':
        return _classifyFeature(path, segments, isGenerated);
      default:
        return FileLocation(
          path: path,
          layer: Layer.other,
          isGenerated: isGenerated,
        );
    }
  }

  static FileLocation _classifyInfrastructure(
    String path,
    List<String> segments,
    bool isGenerated,
  ) {
    // infrastructure/adapters/<feature>/...
    if (segments.length >= 4 && segments[1] == adaptersSegment) {
      return FileLocation(
        path: path,
        layer: Layer.adapter,
        feature: segments[2],
        isGenerated: isGenerated,
      );
    }

    return FileLocation(
      path: path,
      layer: Layer.infrastructure,
      isGenerated: isGenerated,
    );
  }

  static FileLocation _classifyFeature(
    String path,
    List<String> segments,
    bool isGenerated,
  ) {
    // features/<name>/<layer>/...
    if (segments.length < 2) {
      return FileLocation(
        path: path,
        layer: Layer.other,
        isGenerated: isGenerated,
      );
    }

    final feature = segments[1];

    if (segments.length < 3) {
      return FileLocation(
        path: path,
        layer: Layer.featureRoot,
        feature: feature,
        isGenerated: isGenerated,
      );
    }

    final layer = switch (segments[2]) {
      'presentation' => Layer.presentation,
      'application' => Layer.application,
      'domain' => Layer.domain,
      _ => Layer.featureRoot,
    };

    return FileLocation(
      path: path,
      layer: layer,
      feature: feature,
      isGenerated: isGenerated,
    );
  }

  /// Whether [path] is a widget or screen.
  ///
  /// Used by the rules that are specifically about UI code rather than about
  /// the presentation layer as a whole -- a controller may legitimately do
  /// things a widget may not.
  static bool isWidgetOrScreen(String path) =>
      path.contains('/screens/') || path.contains('/widgets/');

  static bool isScreen(String path) => path.contains('/screens/');

  static bool isController(String path) => path.contains('/controllers/');

  /// The parts of a feature's application layer an adapter may import.
  ///
  /// Ports are what the adapter implements, contracts are what other features
  /// publish, and events are the vocabulary an adapter announces in. A
  /// coordinator or a piece of shared state is the application's own business,
  /// and an adapter that imported one would have the dependency pointing the
  /// wrong way -- the coordinator depends on the adapter through a port, never
  /// the reverse.
  static bool isApplicationBoundary(String path) =>
      path.contains('/application/ports/') ||
      path.contains('/application/contracts/') ||
      path.contains('/application/events/');
}
