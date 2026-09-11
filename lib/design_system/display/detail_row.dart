import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../localization/ds_localization.dart';
import '../overlays/app_snackbar.dart';
import '../primitives/bidi_text.dart';

/// A label and its value: how a record reads, rather than how it is picked.
///
/// `AppListItem` is a row somebody taps to go somewhere, and its title carries
/// the weight. A record's details read the other way round: a quiet label,
/// then the value that matters, and nowhere to go. The value wraps rather than
/// clipping — an address cut off at the edge is an address nobody can use.
///
/// **Identifiers keep their own shape.** A phone number, an email or an order
/// reference is written left to right in every language. [identifier] lays it
/// out that way on an Arabic page too, where the paragraph would otherwise
/// carry a phone number's "+" to its far end.
class AppDetailRow extends StatelessWidget {
  const AppDetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.identifier = false,
    this.copyable = false,
    this.trailing,
    super.key,
  });

  final String label;

  /// Text, not a widget: copying it and finding its direction both need the
  /// words themselves.
  final String value;

  final IconData? icon;

  /// A phone number, an email, a reference: laid out in its own direction.
  final bool identifier;

  /// Offers to copy [value], and says so once it has.
  final bool copyable;

  /// Anything else the row can do, at its end, after the copy action.
  final Widget? trailing;

  void _copy(BuildContext context) {
    unawaited(Clipboard.setData(ClipboardData(text: value)));
    AppSnackbar.show(context, message: context.strings.copied);
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final TextStyle valueStyle = context.type.bodyMd.copyWith(
      color: colors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.sm,
      ),
      child: Row(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          if (icon != null) Icon(icon, size: 20, color: colors.textMuted),
          Expanded(
            // One sentence to a screen reader: the label, then the value.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: TajeerSpacing.xs2,
                children: <Widget>[
                  Text(
                    label,
                    style: context.type.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  if (identifier)
                    AppBidiText(value, style: valueStyle, alignToAmbient: true)
                  else
                    Text(value, style: valueStyle),
                ],
              ),
            ),
          ),
          if (copyable)
            AppButton.icon(
              icon: const Icon(LucideIcons.copy),
              semanticLabel: '${context.strings.copy} $label',
              onPressed: () => _copy(context),
            ),
          ?trailing,
        ],
      ),
    );
  }
}
