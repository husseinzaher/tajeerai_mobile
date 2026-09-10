/// The theme layer's public face.
///
/// One import gets a widget everything it needs to be drawn correctly: the
/// palette and its accessors, the type scale, spacing, radii, elevation and
/// motion. Design-system components import this and nothing else from `app/`.
///
/// The values behind all of it live in `design/tokens.json`, and reach Dart
/// through `tokens.g.dart`, which `tool/build_tokens.dart` writes. Nothing here
/// holds a colour, a size or a duration of its own.
library;

export 'app_theme.dart';
export 'colors.dart';
export 'motion.dart';
export 'theme_mode_manager.dart';
export 'tokens.g.dart';
export 'typography.dart';
