import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';

/// A compact inline error, for a form or the top of a screen.
///
/// The bordered destructive notice: a hairline in `dangerDefault` at half
/// strength, with the icon and the text on the same colour. It states one
/// problem in one line and offers no action — an action belongs to
/// [AppErrorState], which owns a whole surface.
class AppInlineError extends StatelessWidget {
  const AppInlineError({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: TajeerRadii.mdAll,
        border: Border.fromBorderSide(
          BorderSide(color: colors.dangerDefault.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          Icon(
            icon ?? LucideIcons.circleAlert,
            size: 16,
            color: colors.dangerDefault,
          ),
          Expanded(
            child: Text(
              message,
              style: context.type.bodySm.copyWith(color: colors.dangerDefault),
            ),
          ),
        ],
      ),
    );
  }
}
