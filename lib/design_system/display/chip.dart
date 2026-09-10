import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../primitives/pressable.dart';

/// A chip: a tag you can select, or remove, or both.
///
/// Not a badge with a tap handler. A badge *states* something — a count, a
/// status — and a reader never touches it; a chip is a control, so it carries a
/// pressed state, a selected state, a focus ring and a 44px target. Giving a
/// badge an `onTap` would have produced something that looks unpressable and
/// is, which is the worst of both.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.leading,
    this.enabled = true,
    this.removeLabel,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Shows a remove affordance with its own hit target, so removing a filter
  /// and opening it are not the same tap.
  final VoidCallback? onRemove;

  final Widget? leading;
  final bool enabled;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color background = selected
        ? colors.primarySoft
        : colors.surfaceMuted;
    final Color foreground = selected ? colors.focus : colors.textSecondary;
    final Color border = selected ? colors.primaryBorder : Colors.transparent;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: onTap != null,
        selected: selected,
        enabled: enabled,
        label: label,
        child: ExcludeSemantics(
          child: AppPressable(
            onTap: enabled ? onTap : null,
            enabled: enabled && onTap != null,
            borderRadius: TajeerRadii.fullAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: EdgeInsetsDirectional.only(
                start: TajeerSpacing.sm,
                end: onRemove == null ? TajeerSpacing.sm : TajeerSpacing.xs2,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: TajeerRadii.fullAll,
                border: Border.fromBorderSide(BorderSide(color: border)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: TajeerSpacing.xs2,
                children: <Widget>[
                  if (leading != null)
                    IconTheme.merge(
                      data: IconThemeData(color: foreground, size: 14),
                      child: leading!,
                    ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.labelMd.copyWith(color: foreground),
                  ),
                  if (onRemove != null)
                    Semantics(
                      button: true,
                      label: removeLabel ?? context.strings.dismiss,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled ? onRemove : null,
                        // Its own target inside the chip: removing a filter and
                        // toggling it must not be the same tap.
                        child: SizedBox.square(
                          dimension: 32,
                          child: Center(
                            child: Icon(
                              LucideIcons.x,
                              size: 14,
                              color: foreground,
                            ),
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
