import 'package:flutter/widgets.dart';

/// The frontend's breakpoints, as Flutter logical pixels.
///
/// Tailwind's scale, which is what the web layouts are written against
/// (`sm:`, `md:`, `lg:`). Reproduced so a "two panes from `md` up" decision
/// lands at the same width on a tablet as it does in a browser.
enum Breakpoint {
  /// < 640: phones. The design's default, since the web classes are mobile-first.
  compact,

  /// >= 640 (`sm:`): large phones and small tablets in portrait.
  medium,

  /// >= 768 (`md:`): tablets. Where the web starts showing rail + detail.
  expanded,

  /// >= 1024 (`lg:`): desktop widths.
  large;

  static const double smMin = 640;
  static const double mdMin = 768;
  static const double lgMin = 1024;

  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static Breakpoint fromWidth(double width) {
    if (width >= lgMin) return Breakpoint.large;
    if (width >= mdMin) return Breakpoint.expanded;
    if (width >= smMin) return Breakpoint.medium;

    return Breakpoint.compact;
  }

  /// True from `md:` up, where the Inbox shows the list and the thread at once
  /// instead of pushing the thread as its own route.
  bool get showsTwoPanes => index >= Breakpoint.expanded.index;
}

/// Picks one of several layouts by breakpoint.
///
/// Falls back down the scale, so a layout only has to name the widths it
/// actually differs at -- the same way `md:flex` leaves smaller widths alone.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    this.large,
    super.key,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;
  final WidgetBuilder? large;

  @override
  Widget build(BuildContext context) {
    final builder = switch (Breakpoint.of(context)) {
      Breakpoint.large => large ?? expanded ?? medium ?? compact,
      Breakpoint.expanded => expanded ?? medium ?? compact,
      Breakpoint.medium => medium ?? compact,
      Breakpoint.compact => compact,
    };

    return builder(context);
  }
}
