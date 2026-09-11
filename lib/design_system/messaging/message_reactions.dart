import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/pressable.dart';
import 'message_data.dart';

/// The reactions under a message.
///
/// A member's own reaction is marked by a tint and an edge together, never the
/// tint alone, and a screen reader hears "you reacted". Tapping one toggles it,
/// when the app allows reacting at all.
class AppMessageReactions extends StatelessWidget {
  const AppMessageReactions({
    required this.reactions,
    this.onToggle,
    super.key,
  });

  final List<AppReactionData> reactions;

  /// Reports the emoji tapped. Without it the reactions are only shown.
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;

    return Wrap(
      spacing: TajeerSpacing.xs2,
      runSpacing: TajeerSpacing.xs2,
      children: <Widget>[
        for (final AppReactionData reaction in reactions)
          Semantics(
            container: true,
            button: onToggle != null,
            selected: reaction.mine,
            label: reaction.mine
                ? '${reaction.emoji} ${reaction.count}, ${strings.youReacted}'
                : '${reaction.emoji} ${reaction.count}',
            onTap: onToggle == null ? null : () => onToggle!(reaction.emoji),
            child: ExcludeSemantics(
              child: AppPressable(
                onTap: onToggle == null
                    ? null
                    : () => onToggle!(reaction.emoji),
                borderRadius: TajeerRadii.fullAll,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 28),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: TajeerSpacing.xs,
                    vertical: TajeerSpacing.xs2,
                  ),
                  decoration: BoxDecoration(
                    color: reaction.mine
                        ? colors.primarySoft
                        : colors.surfaceMuted,
                    borderRadius: TajeerRadii.fullAll,
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: reaction.mine
                            ? colors.primaryBorder
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TajeerSpacing.xs2,
                    children: <Widget>[
                      Text(reaction.emoji, style: context.type.bodySm),
                      Text(
                        '${reaction.count}',
                        style: context.type.labelSm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
