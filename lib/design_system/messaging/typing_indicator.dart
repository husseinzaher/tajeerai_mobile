import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import 'message_bubble.dart';

/// Somebody on the other side is writing.
///
/// Three dots in an incoming bubble, where their message is about to land. The
/// dots pulse in turn; with reduced motion they hold still, because the words
/// are what a screen reader and a still frame both carry. A live region, so the
/// arrival is announced without anybody going to look.
class AppTypingIndicator extends StatefulWidget {
  const AppTypingIndicator({this.name, super.key});

  /// Who is typing. Without one it says "Typing…".
  final String? name;

  @override
  State<AppTypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<AppTypingIndicator>
    with SingleTickerProviderStateMixin {
  // A breathing rhythm rather than a transition, so not one of the motion
  // tokens: those are how long a change takes, and this never finishes.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here rather than in initState: reduced motion can be switched on
    // while the indicator is showing, and a MediaQuery read listens for that.
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Up over the first 40% of a dot's turn, down over the next, then at rest.
  double _opacity(int dot) {
    if (_still) {
      return 1;
    }
    final double t = (_pulse.value - dot * 0.18) % 1.0;
    if (t < 0.4) {
      return 0.35 + 0.65 * (t / 0.4);
    }
    if (t < 0.8) {
      return 1 - 0.65 * ((t - 0.4) / 0.4);
    }
    return 0.35;
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final String? name = widget.name;
    final String label = name == null
        ? strings.typing
        : AppMessages.interpolate(strings.typingName, <String, Object?>{
            'name': name,
          });
    final BorderRadiusDirectional radius = AppMessageBubble.radiusFor(
      outgoing: false,
      startsRun: true,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TajeerSpacing.sm,
              vertical: TajeerSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: context.elevation.card.tone,
              borderRadius: radius,
              border: Border.fromBorderSide(
                BorderSide(color: context.elevation.card.hairline),
              ),
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (BuildContext context, Widget? child) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: TajeerSpacing.xs2,
                children: <Widget>[
                  for (int dot = 0; dot < 3; dot++)
                    Opacity(
                      opacity: _opacity(dot),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
