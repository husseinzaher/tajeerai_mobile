import 'package:flutter/animation.dart';

/// Press, hover and panel timing, from `tokens.json`'s `motion` group.
///
/// One duration and one curve for the whole product is the point of the token:
/// a screen that picks its own easing reads as a different app even when every
/// colour matches.
abstract final class TajeerMotion {
  /// `motion.duration` -- long enough to read as motion, short enough that a
  /// rapid tapper never waits on it.
  static const Duration duration = Duration(milliseconds: 150);

  /// `motion.easing` -- cubic-bezier(0.32, 0.72, 0, 1).
  static const Curve easing = Cubic(0.32, 0.72, 0, 1);

  /// `motion.pressScale` -- what a pressable drops to while held.
  static const double pressScale = 0.98;

  /// Panels (sheets, dialogs) run slower than a press, matching the web
  /// theme's 300/500ms sheet transitions.
  static const Duration panelDuration = Duration(milliseconds: 300);
}
