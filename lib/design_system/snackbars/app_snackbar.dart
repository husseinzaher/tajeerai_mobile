import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';

/// The tone of a transient notice.
enum SnackbarTone { neutral, success, warning, destructive }

/// The system's toast.
///
/// `sonner.tsx`/`toast.tsx` render a `popover`-surfaced card with a border and
/// `shadow-lg`, tinted by tone. Exposed as static helpers rather than a widget
/// because a toast is always shown imperatively -- there is no place in a tree
/// where one belongs.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarTone tone = SnackbarTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);

    final (icon, accent) = switch (tone) {
      SnackbarTone.neutral => (null, colors.textPrimary),
      SnackbarTone.success => (LucideIcons.circleCheck, colors.successDefault),
      SnackbarTone.warning => (
        LucideIcons.triangleAlert,
        colors.warningDefault,
      ),
      SnackbarTone.destructive => (
        LucideIcons.circleAlert,
        colors.dangerDefault,
      ),
    };

    // A queued backlog of stale toasts is worse than losing one: the newest
    // notice is the one the reader acted for.
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(TajeerSpacing.md),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TajeerSpacing.md,
          vertical: TajeerSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: TajeerRadii.lgAll,
          side: BorderSide(
            color: tone == SnackbarTone.neutral ? colors.border : accent,
          ),
        ),
        content: Row(
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            if (icon != null) Icon(icon, size: 16, color: accent),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: colors.primary,
                onPressed: onAction,
              ),
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, tone: SnackbarTone.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, tone: SnackbarTone.destructive);

  /// Kept for the shadow token to stay referenced from one place; the
}
