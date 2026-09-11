import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
