import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

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
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;

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

    return Semantics(
      label: name,
      image: true,
      child: Container(
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
          fontSize: size * 0.36,
          fontWeight: FontWeight.w500,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}
