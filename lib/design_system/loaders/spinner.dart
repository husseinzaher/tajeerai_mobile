import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';

/// The system's loading indicator.
///
/// `spinner.tsx` is lucide's `Loader2` under `animate-spin`, so this rotates
/// the same glyph rather than substituting Material's arc -- the two read as
/// different products side by side.
class AppSpinner extends StatefulWidget {
  const AppSpinner({this.size = 16, this.color, this.semanticLabel, super.key});

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  State<AppSpinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? context.strings.loading,
      liveRegion: true,
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          LucideIcons.loaderCircle,
          size: widget.size,
          color: widget.color ?? context.colors.textMuted,
        ),
      ),
    );
  }
}
