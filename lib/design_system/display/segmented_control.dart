import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A row of mutually exclusive choices, sized to fit together.
///
/// A **form control**, not navigation — see [AppTabs] for the difference and
/// why the two are not one widget. It announces `inMutuallyExclusiveGroup`,
/// which is what tells a screen reader that picking one un-picks the others.
///
/// For two to four short options. Past that the labels stop fitting on a phone
/// and the honest control is [AppSelect] or a radio group.
///
/// At a large text size the segments share the row and their labels ellipsize,
/// rather than pushing the control off the screen. Sharing needs a bounded
/// width, as it does for any row that divides its space.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// Ordered: a `Map` literal preserves insertion order in Dart, and the order
  /// on screen is the order written.
  final Map<T, String> options;

  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(TajeerSpacing.xs2),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: TajeerRadii.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final MapEntry<T, String> option in options.entries)
              Flexible(
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: option.key == value,
                  enabled: _interactive,
                  label: option.value,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _interactive ? () => onChanged!(option.key) : null,
                      child: AnimatedContainer(
                        duration: context.motion.fast,
                        curve: context.motion.standard,
                        constraints: const BoxConstraints(minHeight: 36),
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: TajeerSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: option.key == value
                              ? colors.primary
                              : Colors.transparent,
                          borderRadius: TajeerRadii.fullAll,
                        ),
                        // Centred without filling. The container's own
                        // alignment would stretch each segment across its
                        // whole share of the row, so a control with room to
                        // spare would stop being as wide as its labels.
                        child: Align(
                          widthFactor: 1,
                          child: Text(
                            option.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.labelSm.copyWith(
                              color: option.key == value
                                  ? colors.primaryForeground
                                  : colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
