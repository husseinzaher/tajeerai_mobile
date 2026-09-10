import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The system's bottom sheet.
///
/// `sheet.tsx` renders side panels on the web because there is room for them;
/// on a phone the same role -- a secondary surface over the current screen --
/// is a bottom sheet, so the *surface* tokens are carried over rather than the
/// side placement. Same `bg-background`, same `p-6`, same `bg-black/80` scrim,
/// same `shadow-lg`.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.description,
    this.showHandle = true,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? description;

  /// The drag handle. A phone convention with no web equivalent: it is what
  /// tells the reader the surface can be dragged away.
  final bool showHandle;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget sheet,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xCC000000), // `bg-black/80`
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TajeerRadii.lg),
        ),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      // Keeps the sheet clear of the home indicator and above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TajeerSpacing.lg), // `p-6`
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TajeerSpacing.md, // `gap-4`
            children: <Widget>[
              if (showHandle)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: TajeerRadii.fullAll,
                    ),
                  ),
                ),
              if (title != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: TajeerSpacing.xs,
                  children: <Widget>[
                    Text(
                      title!,
                      style: context.text.titleLarge?.copyWith(
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description!,
                        style: context.text.bodyMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
