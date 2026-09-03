/// The spacing scale.
///
/// `tokens.json` carries a single `spacing.base` of `0.25rem` that components
/// multiply, which is Tailwind's scale: `p-2` is two steps, `p-6` is six. The
/// named steps here are those multiples at the browser's 16px root, so a
/// padding lifted from a `.tsx` file lands on the same number of logical
/// pixels here.
abstract final class TajeerSpacing {
  /// `spacing.base` -- 0.25rem at a 16px root.
  static const double base = 4;

  static const double x0 = 0;
  static const double x0_5 = base * 0.5; // 2
  static const double x1 = base; // 4
  static const double x1_5 = base * 1.5; // 6
  static const double x2 = base * 2; // 8
  static const double x2_5 = base * 2.5; // 10
  static const double x3 = base * 3; // 12
  static const double x4 = base * 4; // 16
  static const double x5 = base * 5; // 20
  static const double x6 = base * 6; // 24
  static const double x8 = base * 8; // 32
  static const double x10 = base * 10; // 40
  static const double x12 = base * 12; // 48
  static const double x16 = base * 16; // 64

  /// Multiplies the base step, for the rare size the named scale misses.
  static double steps(double count) => base * count;
}
