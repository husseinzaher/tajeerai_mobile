import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// What a banner is saying.
///
/// [warning] is a condition, not a failure — being offline is a normal state
/// for this app and the cached data on screen is still valid, so it must not
/// wear the danger colour.
enum AppStatusTone { warning, success, info, neutral }

/// A full-width notice strip, pinned under a toolbar.
///
/// Deliberately not an error surface: it reports a condition the member cannot
/// act on and does not need to dismiss. It says one sentence and gets out of
/// the way.
class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    required this.message,
    this.icon,
    this.tone = AppStatusTone.warning,
    super.key,
  });

  final String message;
  final IconData? icon;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final (Color background, Color foreground) = switch (tone) {
      AppStatusTone.warning => (colors.warningDefault, colors.textInverse),
      AppStatusTone.success => (colors.successDefault, colors.textInverse),
      AppStatusTone.info => (colors.infoDefault, colors.textInverse),
      AppStatusTone.neutral => (colors.surfaceMuted, colors.textMuted),
    };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          if (icon != null) Icon(icon, size: 14, color: foreground),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.type.labelSm.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
