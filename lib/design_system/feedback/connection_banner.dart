import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../display/status_dot.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import 'status_banner.dart';

/// Whether what is on screen is current.
enum AppConnectionStatus {
  /// Caught up, or not yet asked. Says nothing on its own.
  current,

  /// A catch-up pass is running.
  syncing,

  /// Known to be behind: offline, or reconnecting.
  offline,

  /// The last catch-up failed. What is on screen is still valid.
  failed,
}

/// The line under a toolbar that says whether the data is current, and what is
/// still waiting to be sent.
///
/// **Synchronisation, not a socket.** A connected client that has not caught up
/// is behind, and a disconnected one that caught up a second ago is current; a
/// green light for the first is the bug this is shaped to avoid.
///
/// Offline is a warning, never danger: the saved data is still valid, and
/// working offline is a normal state for this app. It draws nothing when there
/// is nothing to say, so a screen mounts it unconditionally, and it is a live
/// region, so a screen reader hears the change without going to look for it.
class AppConnectionBanner extends StatelessWidget {
  const AppConnectionBanner({
    required this.status,
    this.pending = 0,
    this.failed = 0,
    super.key,
  });

  final AppConnectionStatus status;

  /// Changes waiting to reach the server.
  final int pending;

  /// Changes that gave up.
  final int failed;

  @override
  Widget build(BuildContext context) {
    final AppMessages strings = context.strings;

    final (String, IconData, AppStatusTone)? notice = switch (status) {
      AppConnectionStatus.syncing => (
        strings.syncing,
        LucideIcons.refreshCw,
        AppStatusTone.neutral,
      ),
      AppConnectionStatus.offline => (
        '${strings.showingSaved}. ${strings.reconnecting}',
        LucideIcons.wifiOff,
        AppStatusTone.warning,
      ),
      AppConnectionStatus.failed => (
        strings.showingSaved,
        LucideIcons.cloudOff,
        AppStatusTone.warning,
      ),
      AppConnectionStatus.current when failed > 0 => (
        AppMessages.interpolate(strings.notSentCount, <String, Object?>{
          'count': failed,
        }),
        LucideIcons.circleAlert,
        AppStatusTone.warning,
      ),
      AppConnectionStatus.current when pending > 0 => (
        AppMessages.interpolate(strings.sendingCount, <String, Object?>{
          'count': pending,
        }),
        LucideIcons.send,
        AppStatusTone.neutral,
      ),
      AppConnectionStatus.current => null,
    };

    if (notice == null) {
      return const SizedBox.shrink();
    }

    final (String message, IconData icon, AppStatusTone tone) = notice;
    return Semantics(
      container: true,
      liveRegion: true,
      child: AppStatusBanner(message: message, icon: icon, tone: tone),
    );
  }
}

/// Whether what is on screen is current, as a dot.
///
/// The banner, for a place with no room for a sentence — beside a title, in a
/// drawer's header. It takes the same [AppConnectionStatus], so the two can
/// never disagree about the same moment, and for the same reason it is not
/// about the socket: a green dot for a client that is connected but has not
/// caught up is the bug ARCHITECTURE §7 is written against.
///
/// Nothing is drawn for [AppConnectionStatus.current], as nothing is drawn for
/// [AppPresence.unknown]: `current` also means "not yet asked", and a green dot
/// would be a confident answer to it.
///
/// Offline and a failed catch-up share a colour — both are warnings, because
/// the data on screen is still valid in both — so the words are what tell them
/// apart. They are always the dot's semantic label, and [showLabel] puts them
/// on screen too. It is not a live region: a screen showing this and the
/// banner would announce every change twice, and the banner is the one that
/// speaks.
class AppConnectionDot extends StatelessWidget {
  const AppConnectionDot({
    required this.status,
    this.showLabel = false,
    this.size = 10,
    this.ringColor,
    super.key,
  });

  final AppConnectionStatus status;

  /// Whether the words sit beside the dot, rather than only reaching a screen
  /// reader.
  final bool showLabel;

  final double size;

  /// The cutout behind the dot. Defaults to the surface it sits on.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;

    final (Color, String)? look = switch (status) {
      AppConnectionStatus.current => null,
      AppConnectionStatus.syncing => (colors.infoDefault, strings.syncing),
      AppConnectionStatus.offline => (colors.warningDefault, strings.offline),
      AppConnectionStatus.failed => (colors.warningDefault, strings.syncFailed),
    };

    if (look == null) {
      return const SizedBox.shrink();
    }

    final (Color color, String label) = look;

    if (!showLabel) {
      return AppStatusDot(
        color: color,
        size: size,
        ringColor: ringColor,
        semanticLabel: label,
      );
    }

    // One run of text with the dot inside it, rather than a Row: it wraps like
    // text at a large type size, and it has no flex to break in a parent with
    // unbounded width.
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: TajeerSpacing.xs2,
                  ),
                  child: AppStatusDot(
                    color: color,
                    size: size,
                    ringColor: ringColor,
                  ),
                ),
              ),
              TextSpan(text: label),
            ],
          ),
          style: context.type.labelSm.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}
