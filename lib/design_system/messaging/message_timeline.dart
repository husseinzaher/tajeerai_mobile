import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../display/labelled_separator.dart';
import '../feedback/async_view.dart';
import '../feedback/empty_state.dart';
import '../feedback/error_state.dart';
import '../loaders/skeleton.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import 'day_and_system_lines.dart';
import 'message_bubble.dart';
import 'message_data.dart';
import 'timeline_builder.dart';
import 'typing_indicator.dart';

/// A thread's messages, newest at the bottom, in all four of its states.
///
/// The list is reversed so it opens pinned to the latest message, and history
/// grows upward as a member scrolls. What it draws comes from
/// [AppTimelineBuilder] — day headings, the unread marker, runs — so this
/// widget only decides how each of those looks.
class AppMessageTimeline extends StatelessWidget {
  const AppMessageTimeline({
    required this.state,
    required this.emptyTitle,
    this.emptyDescription,
    this.unreadCount = 0,
    this.typing = false,
    this.typingName,
    this.onRetry,
    this.onDiscard,
    this.onLongPress,
    this.controller,
    this.now,
    super.key,
  });

  /// The messages, oldest first.
  final AppViewState<List<AppMessageData>> state;

  final String emptyTitle;
  final String? emptyDescription;

  /// The newest incoming messages that are unread. See [AppTimelineBuilder].
  final int unreadCount;

  /// Whether the other side is typing. The indicator sits below the newest
  /// message, even in a thread that has none yet.
  final bool typing;
  final String? typingName;

  final ValueChanged<AppMessageData>? onRetry;
  final ValueChanged<AppMessageData>? onDiscard;
  final ValueChanged<AppMessageData>? onLongPress;

  final ScrollController? controller;

  /// What "today" is, for the day headings.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return AppAsyncView<List<AppMessageData>>(
      state: state,
      loading: (BuildContext context) => const _Placeholders(),
      isEmpty: (List<AppMessageData> messages) => messages.isEmpty && !typing,
      empty: (BuildContext context) => _Scrollable(
        child: AppEmptyState(
          title: emptyTitle,
          description: emptyDescription,
          icon: LucideIcons.messageSquare,
          bordered: false,
        ),
      ),
      error: (AppViewFailed<List<AppMessageData>> failure) => _Scrollable(
        child: AppErrorState(
          message: failure.message,
          onRetry: failure.onRetry,
          bordered: false,
        ),
      ),
      data: (List<AppMessageData> messages) => _list(context, messages),
    );
  }

  Widget _list(BuildContext context, List<AppMessageData> messages) {
    final AppMessages strings = context.strings;
    final List<AppTimelineEntry> entries = AppTimelineBuilder.build(
      messages,
      unreadCount: unreadCount,
    );
    final int lead = typing ? 1 : 0;

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.all(TajeerSpacing.md),
      itemCount: entries.length + lead,
      itemBuilder: (BuildContext context, int index) {
        if (index < lead) {
          return Padding(
            padding: const EdgeInsets.only(top: TajeerSpacing.sm),
            child: AppTypingIndicator(name: typingName),
          );
        }

        final AppTimelineEntry entry =
            entries[entries.length - 1 - (index - lead)];

        return switch (entry) {
          AppTimelineDay(:final DateTime day) => AppDateSeparator(
            day: day,
            now: now,
          ),
          AppTimelineUnread(:final int count) => Padding(
            padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
            child: Semantics(
              header: true,
              child: AppLabelledSeparator(
                label: AppMessages.interpolate(
                  strings.unreadCount,
                  <String, Object?>{'count': count},
                ),
                tone: AppSeparatorTone.primary,
              ),
            ),
          ),
          AppTimelineMessage(
            :final AppMessageData message,
            :final bool startsRun,
            :final bool endsRun,
          ) =>
            message.kind == AppMessageKind.system
                ? AppSystemMessage(text: message.text ?? '')
                : Padding(
                    padding: EdgeInsets.only(
                      // A run reads as one block; a new one starts with air.
                      top: startsRun ? TajeerSpacing.sm : TajeerSpacing.xs2,
                    ),
                    child: AppMessageBubble(
                      message: message,
                      startsRun: startsRun,
                      endsRun: endsRun,
                      onRetry: onRetry == null
                          ? null
                          : () => onRetry!(message),
                      onDiscard: onDiscard == null
                          ? null
                          : () => onDiscard!(message),
                      onLongPress: onLongPress == null
                          ? null
                          : () => onLongPress!(message),
                    ),
                  ),
        };
      },
    );
  }
}

/// A message that still scrolls, and is centred when there is room for it.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(child: child),
          ),
        ),
  );
}

/// Bubbles that are not there yet, on alternating sides.
class _Placeholders extends StatelessWidget {
  const _Placeholders();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: context.strings.loading,
    child: ExcludeSemantics(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(TajeerSpacing.md),
        itemCount: 6,
        itemBuilder: (BuildContext context, int index) {
          final bool outgoing = index.isOdd;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
            child: Align(
              alignment: outgoing
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: AppSkeleton(
                width: outgoing ? 180 : 220,
                height: 40,
                borderRadius: TajeerRadii.lgAll,
              ),
            ),
          );
        },
      ),
    ),
  );
}
