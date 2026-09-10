import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../localization/ds_localization.dart';
import 'empty_state.dart';

/// The "something went wrong" surface.
///
/// Composed from [AppEmptyState] rather than written again: the two differ in
/// tone, not in layout, and duplicating the structure is how they drift apart.
///
/// It takes a message a human can act on — never an exception's `toString`.
/// Mapping a failure to that message is the presentation layer's job, and the
/// error model exists so a screen never has to reach for the infrastructure
/// type to do it.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
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
    return AppEmptyState(
      title: title ?? context.strings.somethingWentWrong,
      description: message,
      icon: LucideIcons.triangleAlert,
      actionLabel: onRetry == null
          ? null
          : (retryLabel ?? context.strings.tryAgain),
      onAction: onRetry,
      bordered: bordered,
    );
  }
}
