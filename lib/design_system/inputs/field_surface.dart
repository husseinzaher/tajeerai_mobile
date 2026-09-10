import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The bordered box every control with an edge is drawn in.
///
/// It exists so the answer to "what colour is this border" is written once.
/// Six controls each deriving `invalid ? danger : border` drift within a
/// month, and the one that drifts is always the one nobody looked at.
///
/// It reports its own focus by watching descendants: the caller hands it a
/// borderless control and does not have to plumb a `FocusNode` through.
class AppFieldSurface extends StatefulWidget {
  const AppFieldSurface({
    required this.child,
    this.invalid = false,
    this.enabled = true,
    this.padding,
    this.minHeight = _minTarget,
    this.onTap,
    super.key,
  });

  /// The platform touch-target floor. A control below it is a defect, not a
  /// dense design.
  static const double _minTarget = 44;

  final Widget child;
  final bool invalid;
  final bool enabled;
  final EdgeInsetsGeometry? padding;

  /// A minimum, never a fixed height: the content grows with the OS text size.
  final double minHeight;

  /// Makes the whole box the hit target, for a control that opens something
  /// rather than accepting typing.
  final VoidCallback? onTap;

  @override
  State<AppFieldSurface> createState() => _AppFieldSurfaceState();
}

class _AppFieldSurfaceState extends State<AppFieldSurface> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color border = switch ((widget.invalid, _focused)) {
      // An error's boundary is `dangerDefault`, never `dangerBorder`: that one
      // is a decorative hairline around a wash and is ~1.5:1 on it.
      (true, _) => colors.dangerDefault,
      (false, true) => colors.focus,
      (false, false) => colors.border,
    };

    final Widget box = AnimatedContainer(
      duration: context.motion.fast,
      curve: context.motion.standard,
      constraints: BoxConstraints(minHeight: widget.minHeight),
      padding:
          widget.padding ??
          const EdgeInsetsDirectional.symmetric(horizontal: TajeerSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: TajeerRadii.mdAll,
        border: Border.fromBorderSide(
          BorderSide(
            color: border,
            width: _focused || widget.invalid ? 1.5 : 1,
          ),
        ),
      ),
      child: widget.child,
    );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Focus(
        // Not focusable itself -- it only wants to hear when whatever it wraps
        // takes focus, and a node that can be focused would put an empty stop
        // in the traversal order.
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (bool focused) => setState(() => _focused = focused),
        child: widget.onTap == null || !widget.enabled
            ? box
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                child: box,
              ),
      ),
    );
  }
}
