import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../feedback/async_view.dart';
import '../feedback/empty_state.dart';
import '../feedback/error_state.dart';
import '../feedback/loading_state.dart';
import 'conversation_list_item.dart';
import 'conversation_summary.dart';

/// The Inbox's list, in all four of its states.
///
/// Loading is placeholder rows shaped like the real ones, so nothing jumps
/// when the first row lands. Empty and failed stay **pullable**: an empty
/// Inbox and one that failed to refresh are exactly the two moments a member
/// reaches for pull-to-refresh, and a centred message with nothing to scroll
/// gives them nowhere to pull.
class AppConversationList extends StatelessWidget {
  const AppConversationList({
    required this.state,
    required this.onOpen,
    required this.emptyTitle,
    this.emptyDescription,
    this.emptyIcon = LucideIcons.messagesSquare,
    this.onLongPress,
    this.onRefresh,
    this.selectedId,
    this.now,
    super.key,
  });

  final AppViewState<List<AppConversationSummary>> state;
  final ValueChanged<AppConversationSummary> onOpen;
  final ValueChanged<AppConversationSummary>? onLongPress;

  /// Pull-to-refresh. Without it the list does not offer the gesture.
  final Future<void> Function()? onRefresh;

  /// Passed in, because what an empty list means is the app's to say: no
  /// conversations yet, or nothing matching a search.
  final String emptyTitle;
  final String? emptyDescription;
  final IconData emptyIcon;

  final String? selectedId;

  /// Handed to every row. See [AppConversationListItem.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return AppAsyncView<List<AppConversationSummary>>(
      state: state,
      loading: (BuildContext context) => const AppLoadingState.list(),
      isEmpty: (List<AppConversationSummary> items) => items.isEmpty,
      empty: (BuildContext context) => _pullable(
        context,
        AppEmptyState(
          title: emptyTitle,
          description: emptyDescription,
          icon: emptyIcon,
          bordered: false,
        ),
      ),
      error: (AppViewFailed<List<AppConversationSummary>> failure) => _pullable(
        context,
        AppErrorState(
          message: failure.message,
          onRetry: failure.onRetry,
          bordered: false,
        ),
      ),
      data: (List<AppConversationSummary> items) => _refreshable(
        context,
        ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs2),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final AppConversationSummary item = items[index];
            return AppConversationListItem(
              conversation: item,
              selected: item.id == selectedId,
              onTap: () => onOpen(item),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(item),
              now: now,
            );
          },
        ),
      ),
    );
  }

  /// A message that still scrolls: centred when there is room, and something
  /// to pull on either way.
  Widget _pullable(BuildContext context, Widget message) => _refreshable(
    context,
    LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Center(child: message),
            ),
          ),
    ),
  );

  Widget _refreshable(BuildContext context, Widget child) {
    final Future<void> Function()? refresh = onRefresh;
    if (refresh == null) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: refresh,
      // `focus`, not `primary`: the brand yellow has no contrast against the
      // light surface the indicator spins on.
      color: context.colors.focus,
      backgroundColor: context.elevation.popover.tone,
      child: child,
    );
  }
}
