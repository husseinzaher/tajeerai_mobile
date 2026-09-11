import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';

/// One tile in a row of "continue with" providers.
///
/// A glyph and nothing else on screen, as the reference draws them — which is
/// exactly why [label] is required rather than optional. A row of three
/// unlabelled marks is three identical buttons to a screen reader, and the
/// only way to make that impossible is to refuse to build one without a name.
///
/// **Not on the production sign-in screen.** Mobile has no OAuth flow yet, and
/// a provider button that does nothing is worse than an absent one. It lives
/// here, documented in the showcase, for the day that flow exists. The brand
/// marks themselves will ship as assets then; the showcase uses neutral glyphs
/// rather than imitating anybody's logo.
class AppSocialButton extends StatelessWidget {
  const AppSocialButton({
    required this.glyph,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final Widget glyph;

  /// "Continue with Google" — the whole sentence, not the provider's name.
  final String label;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final bool enabled = onPressed != null;

    return Semantics(
      // `container: true` or no node survives: the subtree is excluded, so
      // there would be nothing for this annotation to merge into.
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AppPressable(
            onTap: onPressed,
            enabled: enabled,
            borderRadius: TajeerRadii.lgAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.elevation.card.tone,
                borderRadius: TajeerRadii.lgAll,
                border: Border.fromBorderSide(BorderSide(color: colors.border)),
              ),
              child: IconTheme(
                data: IconThemeData(color: colors.textPrimary, size: 24),
                child: glyph,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
