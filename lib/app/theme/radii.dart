import 'package:flutter/widgets.dart';

/// The corner-radius scale.
///
/// `tokens.json` carries `radius.base` (0.7rem = 11.2px) and the web theme
/// derives the rest from it arithmetically:
/// `sm = base - 4`, `md = base - 2`, `lg = base`, `xl = base + 4`.
/// Reproduced as arithmetic rather than four literals so changing the token
/// still moves all four together.
abstract final class TajeerRadii {
  /// `radius.base` -- 0.7rem at a 16px root.
  static const double base = 11.2;

  static const double sm = base - 4; // 7.2
  static const double md = base - 2; // 9.2
  static const double lg = base; // 11.2
  static const double xl = base + 4; // 15.2

  /// Pills and avatars. Large enough to fully round anything in the system.
  static const double full = 9999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
