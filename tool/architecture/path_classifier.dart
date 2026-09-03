/// Where a file sits in the architecture.
///
/// Every rule is expressed in terms of these, not in terms of path substrings,
/// so a rule reads as "presentation must not import data" rather than as a
/// string comparison nobody can audit.
enum Layer {
  /// `app/` -- bootstrap, routing, config, theme, localization.
  app,

  /// `design_system/` -- business-agnostic UI.
  designSystem,

  /// `infrastructure/` -- technical implementations.
  infrastructure,

  /// `failures/` -- the framework-free failure taxonomy every layer may use.
  failures,

  /// `features/<name>/presentation/`
  presentation,

  /// `features/<name>/application/`
  application,

  /// `features/<name>/domain/`
  domain,

  /// `features/<name>/data/`
  data,

  /// `features/<name>/realtime/`
  featureRealtime,

  /// A file under `features/<name>/` in no recognised layer.
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

  /// The owning feature, for anything under `features/`.
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
        return FileLocation(
          path: path,
          layer: Layer.infrastructure,
          isGenerated: isGenerated,
        );
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
      'data' => Layer.data,
      'realtime' => Layer.featureRealtime,
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
}
