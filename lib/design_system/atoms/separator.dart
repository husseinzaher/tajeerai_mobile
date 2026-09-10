import 'package:flutter/widgets.dart';

import '../../app/theme/theme.dart';

/// A hairline rule.
///
/// `separator.tsx`: `bg-border`, 1px on the cross axis and filling the main
/// one. A widget rather than a raw `Divider` so the thickness and colour come
/// from the token in one place.
class AppSeparator extends StatelessWidget {
  const AppSeparator({this.axis = Axis.horizontal, this.indent = 0, super.key});

  const AppSeparator.vertical({this.indent = 0, super.key})
    : axis = Axis.vertical;

  final Axis axis;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.border;

    return axis == Axis.horizontal
        ? Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: indent),
            child: SizedBox(
              height: 1,
              width: double.infinity,
              child: ColoredBox(color: color),
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(vertical: indent),
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: color),
            ),
          );
  }
}
