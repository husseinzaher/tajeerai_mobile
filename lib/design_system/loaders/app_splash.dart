import 'package:flutter/material.dart';

import 'spinner.dart';

import '../../app/theme/theme.dart';

/// The screen shown while the session is being resolved.
///
/// Painted on `background` with the system's own spinner so the very first
/// frame already belongs to the product, rather than being a white rectangle
/// that flashes before the theme applies.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.background,
      child: Center(child: Spinner(size: 24, color: context.colors.primary)),
    );
  }
}
