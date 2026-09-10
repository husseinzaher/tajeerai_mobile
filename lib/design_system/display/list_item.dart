import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';

/// A row: something on the start, something to read, something on the end.
///
/// Replaces Material's `ListTile`, which brings its own typography, its own
/// density and its own idea of what a leading widget is sized to — three things
/// this system already decides. Every slot here is a `Widget`, so the row never
/// has to know what a conversation, a customer or a channel is.
class AppListItem extends StatelessWidget {
  const AppListItem({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,

    /// The small print at the end of the title line — a timestamp, usually.
    /// Separate from [trailing] because it belongs to the *title's* baseline,
    /// not to the row's centre.
    this.meta,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.emphasised = false,
    this.padding,
    this.semanticLabel,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? meta;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool enabled;

  /// Unread, in practice: the title goes to full weight and full ink.
  ///
  /// A flag rather than a caller styling the title itself, so every list that
  /// has an unread state renders it the same way.
  final bool emphasised;

  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Semantics(
      selected: selected,
      enabled: enabled,
      button: onTap != null,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AppPressable(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          enabled: enabled && onTap != null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding:
                padding ??
                const EdgeInsetsDirectional.symmetric(
                  horizontal: TajeerSpacing.md,
                  vertical: TajeerSpacing.sm,
                ),
            decoration: BoxDecoration(
              color: selected ? colors.primarySoft : Colors.transparent,
              border: BorderDirectional(
                // A selected row is marked on the START edge, so the marker is
                // on the right in Arabic — where the eye enters the row.
                start: BorderSide(
                  color: selected ? colors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                ?leading,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: TajeerSpacing.xs2,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: TajeerSpacing.xs,
                        children: <Widget>[
                          Expanded(
                            child: DefaultTextStyle.merge(
                              style: emphasised
                                  ? context.type.titleSm.copyWith(
                                      fontWeight: FontWeight.w700,
                                    )
                                  : context.type.titleSm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: title,
                            ),
                          ),
                          if (meta != null)
                            DefaultTextStyle.merge(
                              style: context.type.caption.copyWith(
                                color: emphasised
                                    ? colors.textSecondary
                                    : colors.textMuted,
                              ),
                              child: meta!,
                            ),
                        ],
                      ),
                      if (subtitle != null)
                        DefaultTextStyle.merge(
                          style: context.type.bodySm.copyWith(
                            color: emphasised
                                ? colors.textSecondary
                                : colors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle!,
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
