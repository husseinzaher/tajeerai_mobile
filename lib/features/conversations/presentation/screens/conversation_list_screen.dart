import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../application/state/sync_state.dart';
import '../../domain/entities/conversation.dart';
import '../controllers/conversation_list_controller.dart';
import '../widgets/async_view_state.dart';
import '../widgets/conversation_view_data.dart';

/// The Inbox rail.
///
/// Composition, and nothing else. The rows, the four states, the banner and
/// the search field are the design system's; what they show is mapped from the
/// domain in `conversation_view_data.dart`. The list reads the local database.
/// Loading is before its first emission, or while the first server pass is
/// still in flight with nothing local to show.
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens a thread, clearing its unread count on the way.
  ///
  /// The write is not awaited: navigation must not wait on a database write,
  /// let alone on a socket command.
  void _open(AppConversationSummary summary) {
    final Conversation? conversation = ref
        .read(conversationListProvider)
        .value
        ?.where((Conversation candidate) => candidate.id == summary.id)
        .firstOrNull;
    if (conversation != null) {
      unawaited(
        ref.read(conversationListControllerProvider).markRead(conversation),
      );
    }
    unawaited(context.push(AppRoutes.conversationDetailPath(summary.id)));
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final ConversationSyncState? sync = ref
        .watch(conversationSyncStateProvider)
        .value;
    final bool searching = ref.watch(conversationSearchProvider).isNotEmpty;

    final bool awaitingFirstInbox = sync?.isAwaitingFirstInboxData ?? true;

    return AppScaffold(
      // The menu button is implied by the signed-in shell's drawer.
      toolbar: AppToolbar(title: strings.inbox, centerTitle: true),
      banner: sync == null || awaitingFirstInbox
          ? null
          : AppConnectionBanner(
              status: sync.connectionStatus,
              pending: sync.pendingMutations,
              failed: sync.failedMutations,
            ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.md),
            child: AppSearchField(
              controller: _search,
              hintText: strings.searchConversations,
              // Filters what is already on the device; no network call.
              onChanged: (String term) =>
                  ref.read(conversationSearchProvider.notifier).update(term),
            ),
          ),
          Expanded(
            child: AppConversationList(
              state: ref
                  .watch(conversationListProvider)
                  .toInboxViewState(
                    (List<Conversation> items) => <AppConversationSummary>[
                      for (final Conversation item in items)
                        item.toSummary(strings),
                    ],
                    sync: sync,
                    searching: searching,
                    failure: strings.conversationsUnreadable,
                    onRetry: () => ref.invalidate(conversationListProvider),
                  ),
              onOpen: _open,
              onRefresh: () =>
                  ref.read(conversationListControllerProvider).refresh(),
              emptyTitle: searching
                  ? context.strings.noMatches
                  : strings.noConversations,
              emptyDescription: searching
                  ? strings.noSearchMatches
                  : strings.noConversationsDescription,
              emptyIcon: searching
                  ? LucideIcons.searchX
                  : LucideIcons.messagesSquare,
            ),
          ),
        ],
      ),
    );
  }
}
