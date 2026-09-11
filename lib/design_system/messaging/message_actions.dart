import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../overlays/action_sheet.dart';
import '../overlays/app_snackbar.dart';
import 'message_data.dart';

/// What a long press on a message offers.
///
/// Copy is the design system's own — it needs nothing but the text — and says
/// so when it is done. Reply, retry and discard are the app's, and appear only
/// when the app hands them in and the message can take them: retry and discard
/// only on a send that failed. A message with nothing to offer opens nothing.
abstract final class AppMessageActions {
  static Future<void> show(
    BuildContext context, {
    required AppMessageData message,
    VoidCallback? onReply,
    VoidCallback? onRetry,
    VoidCallback? onDiscard,
  }) async {
    final AppMessages strings = context.strings;
    final String? text = message.text;

    final List<AppAction> actions = <AppAction>[
      if (text != null && text.trim().isNotEmpty)
        AppAction(
          label: strings.copy,
          icon: LucideIcons.copy,
          onSelected: () {
            unawaited(Clipboard.setData(ClipboardData(text: text)));
            if (context.mounted) {
              AppSnackbar.show(context, message: strings.copied);
            }
          },
        ),
      if (onReply != null)
        AppAction(
          label: strings.reply,
          icon: LucideIcons.reply,
          onSelected: onReply,
        ),
      if (message.canRetry && onRetry != null)
        AppAction(
          label: strings.retry,
          icon: LucideIcons.rotateCw,
          onSelected: onRetry,
        ),
      if (message.canRetry && onDiscard != null)
        AppAction(
          label: strings.discard,
          icon: LucideIcons.trash2,
          destructive: true,
          onSelected: onDiscard,
        ),
    ];

    if (actions.isEmpty) {
      return;
    }
    await AppActionSheet.show(context: context, actions: actions);
  }
}
