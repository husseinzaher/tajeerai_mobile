import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// How strongly a press or hover washes the surface underneath.
///
/// Mirrors the web theme's two elevate steps. `elevate1` is the quieter of the
/// two and carries hover; `elevate2` carries the press, and is what a primary
/// button uses for both.
enum ElevateStep { none, one, two }

/// The interaction primitive every pressable surface in the system is built
/// from.
///
/// The web design system does not swap a surface's colour on hover or press --
/// it paints a translucent overlay *over* whatever is already there
/// (`hover-elevate`, `active-elevate-2`). That is what lets one button variant
/// sit on a card, a sidebar and a coloured surface and stay legible on all
/// three, and it is reproduced here rather than reinvented as a set of
/// per-variant pressed colours.
///
/// The press also scales to `motion.pressScale`, and both the overlay and the
/// scale run on the shared `motion.duration`/`motion.easing` so a press here
/// feels like a press on the web.
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverStep = ElevateStep.one,
    this.pressStep = ElevateStep.two,
    this.scaleOnPress = true,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.excludeSemantics = false,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Clips the overlay to the surface's own corners. Left null the overlay is
  /// square, which is visible on anything rounded.
  final BorderRadius? borderRadius;

  final ElevateStep hoverStep;
  final ElevateStep pressStep;
  final bool scaleOnPress;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final bool excludeSemantics;
  final HitTestBehavior behavior;

  bool get _interactive => enabled && (onTap != null || onLongPress != null);

  @override
  State<AppPressable> createState() => _PressableState();
}

class _PressableState extends State<AppPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  Color _overlay(BuildContext context) {
    final colors = context.colors;

    // Press wins over hover: a held pointer is also inside the surface, and
    // stacking both would produce a third, undesigned shade.
    final step = _pressed
        ? widget.pressStep
        : _hovered
        ? widget.hoverStep
        : ElevateStep.none;

    return switch (step) {
      ElevateStep.none => const Color(0x00000000),
      ElevateStep.one => colors.overlayHover,
      ElevateStep.two => colors.overlayPressed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget._interactive;
    final radius = widget.borderRadius ?? BorderRadius.zero;

    Widget content = AnimatedScale(
      scale: _pressed && widget.scaleOnPress && interactive
          ? context.motion.pressScale
          : 1,
      duration: context.motion.fast,
      curve: context.motion.emphasized,
      child: Stack(
        children: <Widget>[
          widget.child,
          // The overlay sits above the child and ignores hit tests, which is
          // the `::after { pointer-events: none }` the web theme relies on.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: context.motion.fast,
                curve: context.motion.emphasized,
                decoration: BoxDecoration(
                  color: interactive
                      ? _overlay(context)
                      : const Color(0x00000000),
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (_focused) {
      // `focus-visible:ring-1 ring-ring`. Drawn outside the surface so it does
      // not shift the content the way a border would.
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(color: context.colors.focus, spreadRadius: 2),
          ],
        ),
        child: content,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: interactive,
      enabled: widget.enabled,
      excludeSemantics: widget.excludeSemantics,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: interactive,
        onFocusChange: (value) => setState(() => _focused = value),
        child: MouseRegion(
          cursor: interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: widget.behavior,
            onTap: interactive ? widget.onTap : null,
            onLongPress: interactive ? widget.onLongPress : null,
            onTapDown: interactive ? (_) => _setPressed(true) : null,
            onTapUp: interactive ? (_) => _setPressed(false) : null,
            onTapCancel: interactive ? () => _setPressed(false) : null,
            child: content,
          ),
        ),
      ),
    );
  }
}
