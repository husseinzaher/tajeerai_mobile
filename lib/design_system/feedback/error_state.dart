import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'empty_state.dart';

import '../../app/theme/theme.dart';

/// The "something went wrong" surface.
///
/// Composed from [EmptyState] rather than written again: the two differ in
/// tone, not in layout, and duplicating the structure is how they drift apart.
///
/// It takes a message a human can act on -- never an exception's `toString`.
/// Mapping a failure to that message is the presentation layer's job, and the
/// error model exists so a screen never has to reach for the infrastructure
/// type to do it.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.bordered = true,
    super.key,
  });

  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title ?? 'Something went wrong',
      description: message,
      icon: LucideIcons.triangleAlert,
      actionLabel: onRetry == null ? null : (retryLabel ?? 'Try again'),
      onAction: onRetry,
      bordered: bordered,
    );
  }
}

/// A compact inline error, for a form or the top of a screen.
///
/// `alert.tsx`'s destructive variant: `rounded-lg border px-4 py-3 text-sm`
/// with the border, icon and text all on `destructive`.
class InlineError extends StatelessWidget {
  const InlineError({required this.message, this.icon, super.key});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16, // `px-4`
        vertical: 12, // `py-3`
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11.2),
        border: Border.fromBorderSide(
          // `border-destructive/50`.
          BorderSide(color: colors.dangerDefault.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: <Widget>[
          Icon(
            icon ?? LucideIcons.circleAlert,
            size: 16,
            color: colors.dangerDefault,
          ),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(
                color: colors.dangerDefault,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A connection/synchronisation notice strip.
///
/// Deliberately not an error: being offline is a normal state for this app,
/// and the cached data on screen is still valid. It uses `warning` rather than
/// `destructive` so it reads as a condition, not a failure.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    required this.message,
    this.icon,
    this.tone = StatusTone.warning,
    super.key,
  });

  final String message;
  final IconData? icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (background, foreground) = switch (tone) {
      StatusTone.warning => (colors.warningDefault, colors.textInverse),
      StatusTone.success => (colors.successDefault, colors.textInverse),
      StatusTone.neutral => (colors.surfaceMuted, colors.textMuted),
    };

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: <Widget>[
          if (icon != null) Icon(icon, size: 14, color: foreground),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { warning, success, neutral }
