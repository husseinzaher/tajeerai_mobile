import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../loaders/skeleton.dart';
import '../loaders/spinner.dart';
import '../localization/ds_localization.dart';

/// Something is on its way.
///
/// Two shapes, because two kinds of wait look different. The default is a
/// spinner, for a wait with no shape of its own. [AppLoadingState.list] draws
/// placeholder rows shaped like the rows they stand in for, so the list does
/// not jump when the first real one lands — and the row a member was about to
/// tap is where it is going to be.
///
/// Either way it is one node to a screen reader, saying "Loading", rather than
/// eight unlabelled grey shapes.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key}) : rows = 0, leading = false;

  const AppLoadingState.list({this.rows = 8, this.leading = true, super.key});

  /// Placeholder rows to draw. Zero draws the spinner.
  final int rows;

  /// Whether each row starts with an avatar-sized circle.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final String label = context.strings.loading;

    if (rows == 0) {
      return Semantics(
        container: true,
        label: label,
        child: const ExcludeSemantics(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(TajeerSpacing.lg),
              child: AppSpinner(),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TajeerSpacing.md,
              vertical: TajeerSpacing.sm,
            ),
            child: Row(
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                if (leading) const AppSkeleton.circle(size: 48),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TajeerSpacing.xs,
                    children: <Widget>[
                      // Two widths, alternating, so the placeholder reads as
                      // a list of different names rather than a barcode.
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: index.isEven ? 0.55 : 0.4,
                        child: const AppSkeleton.text(),
                      ),
                      const AppSkeleton.text(width: double.infinity),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
