import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../loaders/skeleton.dart';

/// A picture from the network, and the three states one is actually in.
///
/// The box exists before the bytes do. A list whose rows grow as photographs
/// arrive reflows under the reader's thumb, and the tap meant for one article
/// lands on the next - so the ratio is declared, the ground is painted, and
/// the image fades in inside a box that was already the right size.
///
/// Deliberately not a caching package. Adding one is an architectural decision
/// (RULE 33 keeps storage packages out of the design system), and Flutter's
/// own `ImageCache` already holds decoded frames for the life of the screen,
/// which is the lifetime a blog read actually needs. What this component does
/// instead is take the *url it is given* - the caller picks which size to ask
/// for - so the saving comes from downloading a 320px copy rather than from
/// downloading a 1536px one twice.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.aspectRatio,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  });

  final String? url;

  /// The shape to reserve. Null lets the image size itself, which is right for
  /// an article body image and wrong for a card.
  final double? aspectRatio;

  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// What the picture shows, for a reader who cannot see it. Null marks it
  /// decorative, which is honest for a cover whose article title is beside it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? TajeerRadii.mdAll;
    final String? source = url;

    final Widget content = source == null || source.isEmpty
        ? _Placeholder(radius: radius)
        : ClipRRect(
            borderRadius: radius,
            child: Image.network(
              source,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              semanticLabel: semanticLabel,
              /*
                A cached image is already complete when this builds, and
                `frame` is then non-null on the first call - so the skeleton
                never flashes over a picture that was ready.
              */
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;

                return _Placeholder(radius: radius);
              },
              errorBuilder: (context, error, stackTrace) =>
                  _Placeholder(radius: radius, failed: true),
            ),
          );

    final double? ratio = aspectRatio;

    return ratio == null || ratio <= 0
        ? content
        : AspectRatio(aspectRatio: ratio, child: content);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.radius, this.failed = false});

  final BorderRadius radius;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    if (!failed) {
      return AppSkeleton(
        width: double.infinity,
        height: double.infinity,
        borderRadius: radius,
      );
    }

    /*
      Says the picture is missing rather than showing a broken-image glyph. A
      reader who sees the platform's default icon concludes the app is broken;
      one who sees a muted frame concludes this article has no photograph,
      which is the truth and is survivable.
    */
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: radius,
      ),
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          /* The same 24 the empty state's icon uses; there is no size token. */
          size: 24,
          color: context.colors.textMuted,
        ),
      ),
    );
  }
}
