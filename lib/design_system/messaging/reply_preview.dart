import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/bidi_text.dart';
import 'message_data.dart';

/// The message a reply quotes: who wrote it, and what it said.
///
/// One strip in two places — above the composer while a reply is being
/// written, with a way to drop it, and inside the bubble that was sent,
/// without one. The bar on the start edge says "this is a quote" before a word
/// of it is read.
class AppReplyPreview extends StatelessWidget {
  const AppReplyPreview({required this.reply, this.onDismiss, super.key});

  final AppReplyData reply;

  /// Drops the reply. Only the composer's strip offers it.
  final VoidCallback? onDismiss;

  /// The quoted message in words, for a media message that has none.
  static String describe(AppReplyData reply, AppMessages strings) =>
      reply.text ??
      switch (reply.kind) {
        AppMessageKind.image => strings.photo,
        AppMessageKind.video => strings.video,
        AppMessageKind.audio => strings.voiceMessage,
        AppMessageKind.document => strings.document,
        AppMessageKind.location => strings.location,
        AppMessageKind.text ||
        AppMessageKind.system ||
        AppMessageKind.unsupported => strings.unsupportedMessage,
      };

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;
    final String quoted = describe(reply, strings);

    return ClipRRect(
      borderRadius: TajeerRadii.mdAll,
      child: ColoredBox(
        color: colors.surfaceMuted,
        // The bar has to be as tall as the quote beside it, whatever the
        // text size makes that.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(width: 3, color: colors.focus),
              Expanded(
                child: Semantics(
                  container: true,
                  label:
                      '${AppMessages.interpolate(strings.replyingTo, <String, Object?>{'name': reply.authorName})}, $quoted',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: TajeerSpacing.sm,
                        vertical: TajeerSpacing.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AppBidiText(
                            reply.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.labelSm.copyWith(
                              color: colors.focus,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppBidiText(
                            quoted,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (onDismiss != null)
                Center(
                  child: AppButton.icon(
                    icon: const Icon(LucideIcons.x),
                    semanticLabel: strings.close,
                    onPressed: onDismiss,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
