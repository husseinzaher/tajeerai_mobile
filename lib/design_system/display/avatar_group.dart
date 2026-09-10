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

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final int shown = names.length <= max ? names.length : max;
    final int overflow = names.length - shown;
    final double overlap = size * 0.3;

    return Semantics(
      label: names.join('، '),
      child: ExcludeSemantics(
        child: SizedBox(
          height: size,
          child: Stack(
            children: <Widget>[
              for (int i = shown - 1; i >= 0; i--)
                PositionedDirectional(
                  start: i * (size - overlap),
                  child: _ringed(
                    context,
                    AppAvatar(
                      name: names[i],
                      imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                      size: size,
                    ),
                  ),
                ),
              if (overflow > 0)
                PositionedDirectional(
                  start: shown * (size - overlap),
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
                        style: context.type.labelSm.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
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
        BorderSide(color: context.colors.surface, width: 2),
      ),
    ),
    child: child,
  );
}
