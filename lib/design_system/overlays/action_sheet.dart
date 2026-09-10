import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../primitives/pressable.dart';
import 'app_bottom_sheet.dart';

/// One thing a member can do from an action sheet.
@immutable
class AppAction {
  const AppAction({
    required this.label,
    required this.onSelected,
    this.icon,
    this.description,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final String? description;

  /// Draws in `dangerDefault` and, by convention, sits last — so the tap that
  /// deletes something is not next to the tap that opens it.
  final bool destructive;

  final bool enabled;
}

/// A list of actions, from the bottom of the screen.
///
/// Composed over [AppBottomSheet] rather than reimplementing it: same surface,
/// same scrim, same drag handle, different content. A second sheet
/// implementation is a second set of safe-area maths and a second answer to
/// what happens when the keyboard is up.
///
/// This is the long-press menu, the overflow menu and the "share to" menu. It
/// is why there is no `ProfileMenu`: that is a toolbar avatar whose tap opens
/// one of these.
abstract final class AppActionSheet {
  static Future<void> show({
    required BuildContext context,
    required List<AppAction> actions,
    String? title,
    String? description,
    bool showCancel = true,
  }) async {
    final AppAction? chosen = await AppBottomSheet.show<AppAction>(
      context: context,
      sheet: AppBottomSheet(
        title: title,
        description: description,
        child: Builder(
          builder: (BuildContext context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TajeerSpacing.xs2,
            children: <Widget>[
              for (final AppAction action in actions)
                _Row(
                  action: action,
                  onTap: () => Navigator.of(context).pop(action),
                ),
              if (showCancel) ...<Widget>[
                const SizedBox(height: TajeerSpacing.xs),
                _Row(
                  action: AppAction(
                    label: context.strings.cancel,
                    onSelected: () {},
                  ),
                  onTap: () => Navigator.of(context).pop(),
                  centred: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Fired after the route is popped, not after it has finished animating
    // out — `show` completes as soon as `Navigator.pop` runs. That is still
    // the ordering that matters: by the time an action runs, the sheet is no
    // longer the route taking input, so an action that opens another one is
    // pushing onto a navigator that has already let go of this.
    chosen?.onSelected();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.action, required this.onTap, this.centred = false});

  final AppAction action;
  final VoidCallback onTap;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final Color ink = action.destructive
        ? colors.dangerDefault
        : colors.textPrimary;

    return Opacity(
      opacity: action.enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        enabled: action.enabled,
        label: action.label,
        child: ExcludeSemantics(
          child: AppPressable(
            onTap: action.enabled ? onTap : null,
            enabled: action.enabled,
            borderRadius: TajeerRadii.mdAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: centred
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  if (action.icon != null)
                    Icon(action.icon, size: 20, color: ink),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: centred
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          action.label,
                          style: context.type.bodyLg.copyWith(color: ink),
                        ),
                        if (action.description != null)
                          Text(
                            action.description!,
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
