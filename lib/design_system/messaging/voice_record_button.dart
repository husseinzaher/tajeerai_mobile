import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';

/// Hold to record a voice note, let go to keep it, slide toward the start edge
/// to throw it away.
///
/// The gesture is the fast path, not the only one. A screen reader cannot hold
/// and slide, so a tap starts recording and a second tap stops it — the same
/// callbacks, reached without a gesture. Recording itself is the app's: this
/// draws the control and reports what the finger did.
class AppVoiceRecordButton extends StatefulWidget {
  const AppVoiceRecordButton({
    required this.recording,
    this.onStart,
    this.onStop,
    this.onCancel,
    super.key,
  });

  /// Whether a recording is running. The app decides, from [onStart] and
  /// [onStop].
  final bool recording;

  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

  /// How far a held finger slides toward the start edge before letting go
  /// throws the recording away.
  static const double cancelDistance = 80;

  @override
  State<AppVoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<AppVoiceRecordButton> {
  bool _held = false;
  bool _cancelled = false;

  void _begin() {
    _held = true;
    _cancelled = false;
    widget.onStart?.call();
  }

  void _move(LongPressMoveUpdateDetails details) {
    if (!_held || _cancelled) {
      return;
    }
    // Toward the start edge: left in English, right in Arabic.
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double toward = rtl
        ? details.offsetFromOrigin.dx
        : -details.offsetFromOrigin.dx;
    if (toward >= AppVoiceRecordButton.cancelDistance) {
      _cancelled = true;
      widget.onCancel?.call();
    }
  }

  void _end() {
    if (_held && !_cancelled) {
      widget.onStop?.call();
    }
    _held = false;
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final bool enabled = widget.onStart != null;
    final VoidCallback? tap = !enabled
        ? null
        : widget.recording
        ? widget.onStop
        : widget.onStart;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.recording ? strings.recording : strings.recordVoice,
      onTap: tap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          onLongPressStart: enabled && !widget.recording
              ? (LongPressStartDetails details) => _begin()
              : null,
          onLongPressMoveUpdate: enabled ? _move : null,
          onLongPressEnd: enabled
              ? (LongPressEndDetails details) => _end()
              : null,
          child: AnimatedContainer(
            duration: context.motion.fast,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.recording
                  ? colors.dangerDefault
                  : Colors.transparent,
            ),
            child: Icon(
              LucideIcons.mic,
              size: 20,
              color: widget.recording
                  ? colors.textInverse
                  : enabled
                  ? colors.textSecondary
                  : colors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}
