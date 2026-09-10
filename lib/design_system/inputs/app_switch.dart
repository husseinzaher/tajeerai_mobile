import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A switch, for a setting that takes effect the moment it is flipped.
///
/// Not interchangeable with [AppCheckbox], and the difference is not visual: a
/// checkbox states an intention that a form will act on later, a switch *is*
/// the action. A switch inside a form with a Save button is a lie about when
/// something happened.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;
  final bool enabled;
  final String? semanticLabel;

  bool get _interactive => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Semantics(
      toggled: value,
      enabled: _interactive,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _interactive ? () => onChanged!(!value) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                spacing: TajeerSpacing.sm,
                children: <Widget>[
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
                  AnimatedContainer(
                    duration: context.motion.fast,
                    curve: context.motion.standard,
                    width: 44,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: value ? colors.primary : colors.surfaceMuted,
                      borderRadius: TajeerRadii.fullAll,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: value
                              ? colors.primaryBorder
                              : colors.borderStrong,
                        ),
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: context.motion.fast,
                      curve: context.motion.standard,
                      // Directional, so the thumb travels toward the end of
                      // the line in Arabic as it does in English.
                      alignment: value
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: value
                              ? colors.primaryForeground
                              : colors.surface,
                          shape: BoxShape.circle,
                          boxShadow: context.elevation.subtle.shadow,
                        ),
                      ),
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
