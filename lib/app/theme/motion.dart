import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// The motion the app is currently allowed to use.
///
/// Two sets, and a component never chooses between them: it reads
/// `context.motion`, which returns the zeroed set when the platform asks for
/// reduced motion. That is the same discipline as no component checking whether
/// the theme is dark, applied to a second axis — and reading it through
/// `MediaQuery` also registers the dependency, so a widget rebuilds when
/// somebody changes the setting without leaving the app.
@immutable
class TajeerMotion {
  const TajeerMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.standard,
    required this.emphasized,
    required this.pressScale,
  });

  /// A press, a ripple, a checkbox.
  final Duration fast;

  /// A theme crossfade, a banner, a state change.
  final Duration normal;

  /// A sheet, a drawer, a page.
  final Duration slow;

  final Curve standard;
  final Curve emphasized;

  /// What a pressable drops to while held.
  final double pressScale;

  static const TajeerMotion standardSet = TajeerMotion(
    fast: TajeerMotionTokens.durationFast,
    normal: TajeerMotionTokens.durationNormal,
    slow: TajeerMotionTokens.durationSlow,
    standard: TajeerMotionTokens.easingStandard,
    emphasized: TajeerMotionTokens.easingEmphasized,
    pressScale: TajeerMotionTokens.pressScale,
  );

  /// Zero durations and no scale.
  ///
  /// The curves are kept rather than nulled: at `Duration.zero` an animation
  /// jumps rather than tweens, so the curve is inert, and keeping them means
  /// every call site stays type-identical between the two sets.
  static const TajeerMotion reducedSet = TajeerMotion(
    fast: Duration.zero,
    normal: Duration.zero,
    slow: Duration.zero,
    standard: TajeerMotionTokens.easingStandard,
    emphasized: TajeerMotionTokens.easingEmphasized,
    pressScale: 1,
  );
}

extension TajeerMotionContext on BuildContext {
  /// The motion set this subtree may use.
  TajeerMotion get motion =>
      (MediaQuery.maybeDisableAnimationsOf(this) ?? false)
      ? TajeerMotion.reducedSet
      : TajeerMotion.standardSet;
}
