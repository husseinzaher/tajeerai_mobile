import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';

/// The "nothing here" surface.
///
/// `empty.tsx`: a centred column with a `size-10 rounded-lg bg-muted` media
/// slot, a `text-lg font-medium` title, muted description, and an optional
/// action. The dashed border the web draws is kept, because it is what marks
/// the region as a placeholder rather than a real card.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.bordered = true,
    super.key,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The web's `border-dashed`. Off when the empty state fills a whole screen,
  /// where a dashed rectangle around the viewport reads as a broken layout.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(TajeerSpacing.lg), // `p-6`
        decoration: bordered
            ? BoxDecoration(
                borderRadius: TajeerRadii.lgAll,
                border: Border.fromBorderSide(BorderSide(color: colors.border)),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: TajeerSpacing.lg, // `gap-6`
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.xs, // `gap-2`
              children: <Widget>[
                if (icon != null)
                  Container(
                    width: 40, // `size-10`
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: TajeerRadii.lgAll,
                    ),
                    child: Icon(icon, size: 24, color: colors.textPrimary),
                  ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  // `text-lg font-medium tracking-tight`.
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
                if (description != null)
                  ConstrainedBox(
                    // `max-w-sm` -- a description that runs the full width of a
                    // tablet is unreadable.
                    constraints: const BoxConstraints(maxWidth: 384),
                    child: Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            if (actionLabel != null && onAction != null)
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outline,
              ),
          ],
        ),
      ),
    );
  }
}
