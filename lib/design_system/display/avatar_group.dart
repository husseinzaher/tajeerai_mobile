import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'avatar.dart';

/// Overlapping avatars, with a count for whoever did not fit.
///
/// The overlap runs toward the *start* of the line, so in Arabic the stack
/// leans the other way and the first person named is still the one on top.
class AppAvatarGroup extends StatelessWidget {
  const AppAvatarGroup({
    required this.names,
    this.imageUrls = const <String?>[],
    this.size = 32,
    this.max = 3,
    super.key,
  });

  final List<String> names;
  final List<String?> imageUrls;
  final double size;

  /// How many faces before the rest become a number.
  final int max;

  /// Width of the cutout drawn around each face.
  static const double _ring = 2;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final int shown = names.length <= max ? names.length : max;
    final int overflow = names.length - shown;
    final int slots = shown + (overflow > 0 ? 1 : 0);

    if (slots == 0) {
      return const SizedBox.shrink();
    }

    // The ring is part of each circle's real footprint. Spacing the faces by
    // `size` alone ignored it, so the drawn overlap was larger than the 30%
    // this is meant to be and the initials crowded each other.
    final double diameter = size + _ring * 2;
    final double step = diameter - size * 0.3;

    // An explicit width. Every child here is positioned, so without it the
    // Stack takes whatever constraints it happens to be handed — the whole row
    // in one parent, nothing at all in another — and the group's size would
    // depend on where somebody dropped it.
    final double width = step * (slots - 1) + diameter;

    return Semantics(
      label: names.join('، '),
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: diameter,
          child: Stack(
            children: <Widget>[
              // Paint order IS stacking order, and it has to run one way. The
              // overflow bubble sits furthest toward the end and tucks under
              // the last face; each face tucks under the one before it; the
              // first person named is on top. The bubble used to be painted
              // last, which put it on top of the last face from the other side
              // — that face was covered on both edges and its initials crowded.
              // The Display golden caught it, and is what will catch it again.
              if (overflow > 0)
                PositionedDirectional(
                  start: shown * step,
                  child: _ringed(
                    context,
                    Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        // Latin digits in both languages: the count is read
                        // against numbers everywhere else in the product.
                        '+$overflow',
                        // Sized to the circle by the avatar's own rule, so
                        // the count and the initials beside it are one size
                        // at every avatar size, not only the default one.
                        style: context.type.labelSm.copyWith(
                          fontSize: size * AppAvatar.initialsScale,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              for (int i = shown - 1; i >= 0; i--)
                PositionedDirectional(
                  start: i * step,
                  child: _ringed(
                    context,
                    AppAvatar(
                      name: names[i],
                      imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                      size: size,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The cutout that keeps two overlapping faces from merging into one shape.
  Widget _ringed(BuildContext context, Widget child) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.fromBorderSide(
        BorderSide(color: context.colors.surface, width: _ring),
      ),
    ),
    child: child,
  );
}
