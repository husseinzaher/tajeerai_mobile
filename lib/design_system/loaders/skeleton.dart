import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A loading placeholder.
///
/// `skeleton.tsx` is `animate-pulse rounded-md bg-primary/10` -- a tinted
/// block that breathes, not a shimmer sweep. Reproduced with the same tint and
/// the same opacity range so a loading list looks like the web's.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height = 16,
    this.borderRadius = TajeerRadii.mdAll,
    super.key,
  });

  /// A one-line text placeholder at the system's `text-sm` line box.
  const Skeleton.text({this.width, super.key})
    : height = 14,
      borderRadius = TajeerRadii.smAll;

  /// A round placeholder for an avatar slot.
  const Skeleton.circle({double size = 40, super.key})
    : width = size,
      height = size,
      borderRadius = TajeerRadii.fullAll;

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  // Tailwind's `animate-pulse` runs opacity between 1 and .5 on an ease-in-out
  // cycle; against a 10% tint that is the 0.10 -> 0.05 range below.
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.10,
    end: 0.05,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: _opacity.value),
              borderRadius: widget.borderRadius,
            ),
          );
        },
      ),
    );
  }
}
