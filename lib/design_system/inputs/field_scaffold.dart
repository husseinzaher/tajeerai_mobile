import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Label, control, and the one message underneath.
///
/// One message, never two: an error replaces the description rather than
/// stacking under it. Two lines of guidance under a field is how a form starts
/// shouting at somebody who has made one mistake.
class AppFieldScaffold extends StatelessWidget {
  const AppFieldScaffold({
    required this.child,
    this.label,
    this.description,
    this.errorText,
    super.key,
  });

  final Widget child;
  final String? label;
  final String? description;
  final String? errorText;

  bool get _invalid => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (label != null)
          Text(
            label!,
            style: context.type.labelMd.copyWith(
              color: _invalid ? colors.dangerDefault : colors.textPrimary,
            ),
          ),
        child,
        if (_invalid)
          Text(
            errorText!,
            style: context.type.bodySm.copyWith(color: colors.dangerDefault),
          )
        else if (description != null)
          Text(
            description!,
            style: context.type.bodySm.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}
