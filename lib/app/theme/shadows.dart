import 'package:flutter/painting.dart';

/// The elevation scale.
///
/// Tailwind's default shadow ramp, which is what the web components reach for
/// (`shadow-xs` on badges, `shadow-sm` on inputs, `shadow` on cards,
/// `shadow-lg` on dialogs and sheets). `tokens.json` does not carry shadows,
/// so the values come from the ramp the components are written against rather
/// than being invented here.
abstract final class TajeerShadows {
  /// `shadow-xs` -- 0 1px 2px 0 rgb(0 0 0 / 0.05)
  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// `shadow-sm` -- 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px …
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: -1,
    ),
  ];

  /// `shadow` -- the card default.
  static const List<BoxShadow> base = sm;

  /// `shadow-md` -- 0 4px 6px -1px, 0 2px 4px -2px
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// `shadow-lg` -- dialogs and sheets.
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> none = <BoxShadow>[];
}
