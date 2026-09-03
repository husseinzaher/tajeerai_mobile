import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/motion.dart';
import '../../app/theme/radii.dart';
import '../../app/theme/spacing.dart';
import '../buttons/app_button.dart';

/// The system's modal.
///
/// `dialog.tsx`: `max-w-lg gap-4 border bg-background p-6 shadow-lg`, a
/// `bg-black/80` scrim, and a zoom-95 + fade entrance. Presented through
/// Flutter's route stack so the platform back gesture dismisses it, which the
/// web gets from Radix's focus trap and Escape handling.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    this.description,
    this.content,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? description;
  final Widget? content;
  final List<Widget> actions;

  /// Shows the dialog and resolves with whatever the dialog pops.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget dialog,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0xCC000000), // `bg-black/80`
      transitionDuration: TajeerMotion.duration,
      pageBuilder: (context, animation, secondary) => dialog,
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: TajeerMotion.easing,
        );

        // `zoom-in-95` + `fade-in-0`.
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// A confirmation with a cancel and a confirm. Returns true only on confirm.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context: context,
      dialog: Builder(
        builder: (context) => AppDialog(
          title: title,
          description: message,
          actions: <Widget>[
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppButton(
              label: confirmLabel,
              variant: destructive
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TajeerSpacing.x6),
        child: ConstrainedBox(
          // `w-full max-w-lg`.
          constraints: const BoxConstraints(maxWidth: 512),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(TajeerSpacing.x6), // `p-6`
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: TajeerRadii.lgAll, // `sm:rounded-lg`
                border: Border.fromBorderSide(BorderSide(color: colors.border)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 15,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TajeerSpacing.x4, // `gap-4`
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: TajeerSpacing.x1_5, // `space-y-1.5`
                    children: <Widget>[
                      Text(
                        title,
                        style: context.text.titleLarge?.copyWith(
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                  ?content,
                  if (actions.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: TajeerSpacing.x2,
                      children: actions,
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
