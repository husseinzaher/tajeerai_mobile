import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';

/// A checkbox, and the label that belongs to it.
///
/// The label is part of the control, not a `Row` somebody assembled beside it:
/// the whole row is the hit target, which is the difference between a checkbox
/// a thumb can hit and one it cannot. That is what the hand-rolled version in
/// the sign-in form was working around.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  /// `null` only when [tristate]-style indeterminacy is being shown.
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool enabled;
  final String? semanticLabel;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final bool checked = value ?? false;

    return Semantics(
      checked: checked,
      enabled: _interactive,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _interactive ? () => onChanged!(!checked) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  AnimatedContainer(
                    duration: context.motion.fast,
                    curve: context.motion.standard,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: checked ? colors.primary : Colors.transparent,
                      borderRadius: TajeerRadii.xsAll,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: checked
                              ? colors.primaryBorder
                              : colors.borderStrong,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: checked
                        ? Icon(
                            LucideIcons.check,
                            size: 14,
                            color: colors.primaryForeground,
                          )
                        : null,
                  ),
                  if (label != null || description != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (label != null)
                            Text(label!, style: context.type.bodyMd),
                          if (description != null)
                            Text(
                              description!,
                              style: context.type.bodySm.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
