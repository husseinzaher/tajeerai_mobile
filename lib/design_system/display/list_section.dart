import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'separator.dart';

/// A titled group of rows, separated and enclosed.
///
/// Deliberately not a scroller. The design system does not own scrolling: a
/// screen knows whether its list is a `ListView`, a `SliverList` or six rows in
/// a `Column`, and wrapping that decision up here would make the long case
/// impossible without a second widget.
class AppListSection extends StatelessWidget {
  const AppListSection({
    required this.children,
    this.title,
    this.bordered = true,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Widget rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) const AppSeparator(indent: TajeerSpacing.md),
          children[i],
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: TajeerSpacing.md,
              end: TajeerSpacing.md,
            ),
            child: Text(
              title!,
              style: context.type.labelSm.copyWith(color: colors.textMuted),
            ),
          ),
        if (!bordered)
          rows
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.elevation.card.tone,
              borderRadius: TajeerRadii.lgAll,
              border: Border.fromBorderSide(
                BorderSide(color: context.elevation.card.hairline),
              ),
            ),
            child: ClipRRect(borderRadius: TajeerRadii.lgAll, child: rows),
          ),
      ],
    );
  }
}
