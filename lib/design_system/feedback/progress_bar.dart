import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A horizontal progress track.
///
/// `value: null` is indeterminate — something is happening and nobody can say
/// how much is left. That is the honest state for a request in flight, and it
/// is a different claim from `value: 0`, which says the work has not started.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    this.value,
    this.semanticLabel,
    this.tone = AppProgressTone.primary,
    super.key,
  });

  /// 0..1, or null for indeterminate.
  final double? value;

  final String? semanticLabel;
  final AppProgressTone tone;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color fill = switch (tone) {
      AppProgressTone.primary => colors.primary,
      AppProgressTone.success => colors.successDefault,
      AppProgressTone.danger => colors.dangerDefault,
    };

    return Semantics(
      label: semanticLabel,
      value: value == null ? null : '${(value! * 100).round()}%',
      child: ClipRRect(
        borderRadius: TajeerRadii.fullAll,
        child: LinearProgressIndicator(
          value: value,
          minHeight: 6,
          backgroundColor: colors.surfaceMuted,
          valueColor: AlwaysStoppedAnimation<Color>(fill),
        ),
      ),
    );
  }
}

enum AppProgressTone { primary, success, danger }
