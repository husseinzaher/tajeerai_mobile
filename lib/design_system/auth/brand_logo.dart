import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';

/// Whether the logo carries the product name beside its mark.
enum AppBrandLogoVariant { mark, full }

/// The Tajeer AI logo.
///
/// TODO(brand): this is a placeholder, and deliberately an obvious one. Replace
/// the mark with the real logo asset — SVG, or PNG at @1x/@2x/@3x — the moment
/// it exists. Until then it is a shopping-bag glyph on the brand yellow, which
/// nobody will mistake for the real mark. That is the point: a near-miss logo is
/// worse than a plain stand-in, because people stop noticing that it is wrong.
///
/// The lockup is pinned left-to-right in every language. A logo is a fixed
/// graphic, not a sentence — mirroring it in Arabic would put the name before
/// the mark and produce a lockup the brand does not have. Same reasoning as the
/// one-time-code field keeping its digits in order.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    this.variant = AppBrandLogoVariant.full,
    this.size = 56,
    this.name = 'Tajeer AI',
    super.key,
  });

  final AppBrandLogoVariant variant;

  /// The mark's edge length.
  final double size;

  /// The wordmark, and what a screen reader calls the whole logo.
  final String name;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    // No outline, even though the yellow has only ~1.5:1 against the warm
    // canvas. A logo is not a control: WCAG's non-text contrast rule exempts
    // logotypes, and an edge would change what the mark looks like.
    final Widget mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: size >= 56 ? TajeerRadii.xlAll : TajeerRadii.mdAll,
      ),
      child: Icon(
        LucideIcons.shoppingBag,
        size: size * 0.5,
        color: colors.primaryForeground,
      ),
    );

    final Widget logo = variant == AppBrandLogoVariant.mark
        ? mark
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: TajeerSpacing.sm,
            children: <Widget>[
              mark,
              Text(name, style: context.type.headlineMd),
            ],
          );

    return Semantics(
      container: true,
      image: true,
      label: name,
      child: ExcludeSemantics(
        child: Directionality(textDirection: TextDirection.ltr, child: logo),
      ),
    );
  }
}
