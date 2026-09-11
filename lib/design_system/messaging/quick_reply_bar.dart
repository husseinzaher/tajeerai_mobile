import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../display/chip.dart';
import '../localization/ds_localization.dart';

/// Replies a member can pick instead of typing.
///
/// Chips in a row that scrolls sideways — from the start edge, so the first
/// suggestion is on the right in Arabic. Picking one fills the composer rather
/// than sending: a suggestion is a draft, and the member still decides.
class AppQuickReplyBar extends StatelessWidget {
  const AppQuickReplyBar({
    required this.replies,
    required this.onSelected,
    super.key,
  });

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.strings.suggestedReplies,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TajeerSpacing.sm,
          vertical: TajeerSpacing.xs,
        ),
        child: Row(
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            for (final String reply in replies)
              AppChip(label: reply, onTap: () => onSelected(reply)),
          ],
        ),
      ),
    );
  }
}
