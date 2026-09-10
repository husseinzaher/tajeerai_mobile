import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Colour behaviour that cannot be a token.
///
/// Deliberately almost empty, and that is the point. The palette this replaced
/// carried four derived fields and a `opaqueBorderFor()` helper that shifted a
/// surface's HSL lightness by a fixed step to invent a border for it. Measured
/// against the old indigo brand that produced an 8.69:1 boundary; against the
/// yellow one it produces **1.94:1**. A lightness delta is not a contrast
/// guarantee, and no amount of retuning makes it one across hues.
///
/// So the palette now carries `primaryHover`, `primaryPressed`, `primarySoft`
/// and `primaryBorder` as real, contrast-tested tokens, and the derivations
/// that existed to fake them have no remaining job.
extension TajeerColorsX on TajeerColors {
  /// Ink for a fill whose colour is not ours to know — a tenant's own brand
  /// hex, arriving from the API at runtime.
  ///
  /// The one case a token file genuinely cannot cover, and the only reason this
  /// extension exists: it gives the next person somewhere correct to go instead
  /// of reaching for the ghost of `opaqueBorderFor`.
  Color inkOn(Color fill) =>
      fill.computeLuminance() > 0.5 ? textPrimary : textInverse;
}
