import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// A small filled circle, optionally ringed.
///
/// One primitive with two semantic wrappers over it — [AppPresenceDot] for a
/// person and `AppConnectionDot` for the socket. They mean entirely different
/// things and must not be interchangeable in a call site, but they are the same
/// eight pixels and there is no reason to draw those twice.
///
/// The ring is what makes it legible on top of something else: a dot on the
/// corner of an avatar has no contrast guarantee against a photograph, so it
/// carries a cutout in the surface colour instead of relying on one.
class AppStatusDot extends StatelessWidget {
  const AppStatusDot({
    required this.color,
    this.size = 10,
    this.ringColor,
    this.semanticLabel,
    super.key,
  });

  final Color color;
  final double size;

  /// The cutout drawn behind the dot. Defaults to the surface it sits on.
  final Color? ringColor;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color ring = ringColor ?? context.colors.surface;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: ring, width: 2)),
        ),
      ),
    );
  }
}

/// Whether somebody is around.
///
/// [unknown] is not [offline]. A member the server has said nothing about and a
/// member the server has said is away are different facts, and collapsing them
/// draws a confident grey dot on a question the app cannot answer.
enum AppPresence { online, away, busy, offline, unknown }

/// A presence dot, coloured by what it means rather than by a caller's choice.
class AppPresenceDot extends StatelessWidget {
  const AppPresenceDot({
    required this.presence,
    this.size = 10,
    this.ringColor,
    this.label,
    super.key,
  });

  final AppPresence presence;
  final double size;
  final Color? ringColor;

  /// Presence is colour-only otherwise, which is invisible to a reader who
  /// cannot distinguish the hues. A caller that shows a dot with no adjacent
  /// text should pass this.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color? color = switch (presence) {
      AppPresence.online => colors.successDefault,
      AppPresence.away => colors.warningDefault,
      AppPresence.busy => colors.dangerDefault,
      AppPresence.offline => colors.textDisabled,
      // Nothing is drawn: an unknown state is not a grey state.
      AppPresence.unknown => null,
    };

    if (color == null) {
      return const SizedBox.shrink();
    }

    return AppStatusDot(
      color: color,
      size: size,
      ringColor: ringColor,
      semanticLabel: label,
    );
  }
}
