import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'status_dot.dart';

/// A round identity image with an initials fallback.
///
/// `avatar.tsx` is `h-10 w-10 rounded-full` over `AvatarImage` with an
/// `AvatarFallback` on `bg-muted`. The fallback here is initials rather than a
/// generic glyph, because a conversation list of identical placeholder icons
/// tells the reader nothing.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.presence = AppPresence.unknown,
    this.badge,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Drawn as a ringed dot at the bottom-end corner.
  ///
  /// Part of the avatar rather than a Stack somebody assembles beside it: the
  /// dot has to sit on the circle's edge, which means it has to know the
  /// radius, and every caller re-deriving that is every caller getting it
  /// slightly differently.
  final AppPresence presence;

  /// A marker at the bottom-end corner — the channel a conversation arrived
  /// on, in the Inbox. Mutually exclusive with [presence] by position: a caller
  /// passing both gets the badge, because a channel is the more specific fact.
  final Widget? badge;

  /// How large initials are drawn, as a fraction of the circle.
  ///
  /// One constant, because it is not only this widget's: `AppAvatarGroup`
  /// draws its "+N" count in the same row of circles and must answer to the
  /// same rule. It used a fixed type step instead, which matched the initials
  /// at the default 32px and looked lost beside 29px letters in an 80px circle.
  static const double initialsScale = 0.36;

  /// At most two letters, taken from the first and last word.
  ///
  /// Works on Arabic and Latin alike because it slices whole characters rather
  /// than assuming a Latin capital exists.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);

    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }

    final first = words.first.characters.take(1).toString();
    final last = words.last.characters.take(1).toString();

    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final Widget? marker =
        badge ??
        (presence == AppPresence.unknown
            ? null
            : AppPresenceDot(presence: presence, size: size * 0.3));

    return Semantics(
      label: name,
      image: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          _circle(context, colors),
          if (marker != null)
            // Directional, so it lands bottom-left in Arabic. The offset is a
            // fraction of the radius rather than a constant: a 32px avatar and
            // a 56px one need the dot in the same *relative* place.
            PositionedDirectional(
              bottom: -size * 0.02,
              end: -size * 0.02,
              child: marker,
            ),
        ],
      ),
    );
  }

  Widget _circle(BuildContext context, TajeerColors colors) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? _fallback(context)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              // A broken avatar must not blank the row it sits in.
              errorBuilder: (context, error, stack) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Center(
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontFamily: TajeerTypography.sansFamily,
          fontFamilyFallback: TajeerTypography.sansFallback,
          fontSize: size * initialsScale,
          fontWeight: FontWeight.w500,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}
