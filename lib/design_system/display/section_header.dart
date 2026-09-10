import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A title, an optional description, and an optional action, in one row.
///
/// One widget rather than three. The web design system splits header, title
/// and description because JSX needs somewhere to hang `space-y-1.5`; three
/// Flutter widgets whose only job is vertical spacing would be ceremony.
///
/// Named for what it is rather than where it started. It began as a card's
/// header, and it is equally the header of a settings group, a sheet, or a
/// section of a screen — a name that says `Card` would have guaranteed a
/// second, identical widget the first time one was needed outside a card.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.description,
    this.trailing,
    super.key,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: TajeerSpacing.xs2,
            children: <Widget>[
              // `titleMd` already carries the weight and the leading this
              // wants. It used to reach for w600 and negative tracking: the
              // first does not exist in Tajawal and silently became bold, and
              // the second severs the joins in a cursive script.
              Text(title, style: context.type.titleMd),
              if (description != null)
                Text(
                  description!,
                  style: context.type.bodySm.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
