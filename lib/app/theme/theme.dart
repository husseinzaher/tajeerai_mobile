/// The theme layer's public face.
///
/// One import gets a widget everything it needs to be drawn correctly: the
/// palette and its accessors, the type scale, spacing, radii, elevation and
/// motion. Design-system components import this and nothing else from `app/`.
///
/// The values behind all of it live in `design/tokens.json`, and reach Dart
/// through `tokens.g.dart`, which `tool/build_tokens.dart` writes. Nothing here
/// holds a colour, a size or a duration of its own.
///
/// **`theme_mode_manager.dart` is deliberately not exported.** It is the only
/// file in this directory that imports Riverpod and the dependency graph, and
/// exporting it would drag both — and, through the graph, drift and its native
/// sqlite — into every design-system file that wanted a colour. That is not
/// theoretical: it is what stopped the showcase compiling for the browser.
/// A caller that needs the manager imports it directly.
library;

export 'app_theme.dart';
export 'colors.dart';
export 'motion.dart';
export 'tokens.g.dart';
export 'typography.dart';
