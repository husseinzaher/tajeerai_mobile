import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/router/routes.dart';
import '../../application/state/sync_state.dart';
import '../../domain/entities/conversation.dart';
import '../controllers/conversation_list_controller.dart';
import '../widgets/conversation_tile.dart';

/// The Inbox rail.
///
/// Every state the screen can be in is handled explicitly: loading, empty,
/// error, and populated. The list itself comes from the local database, so
/// "loading" is the brief moment before the first database emission -- not a
/// network wait.
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

  void _open(Conversation conversation) {
    unawaitedMarkRead(conversation);
    context.push(AppRoutes.conversationDetailPath(conversation.id));
  }

  /// Clears unread as the thread opens. Not awaited: the navigation must not
  /// wait on a database write, let alone on a socket command.
  void unawaitedMarkRead(Conversation conversation) {
    ref.read(conversationListControllerProvider).markRead(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationListProvider);
    final sync = ref.watch(conversationSyncStateProvider);

    return AppScaffold(
      title: 'Inbox',
      actions: <Widget>[
        AppButton.icon(
          icon: const Icon(LucideIcons.logOut),
          semanticLabel: 'Sign out',
          onPressed: () =>
              ref.read(conversationListControllerProvider).signOut(),
        ),
        const SizedBox(width: TajeerSpacing.xs),
      ],
      banner: switch (sync.value) {
        null => null,
        final state => _SyncBanner(state: state),
      },
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.md),
            child: AppSearchField(
              controller: _search,
              hintText: 'Search conversations',
              // Filters what is already on the device -- no network call.
              onChanged: (term) =>
                  ref.read(conversationSearchProvider.notifier).update(term),
            ),
          ),
          Expanded(
            child: conversations.when(
              loading: () => const _ConversationListSkeleton(),
              error: (error, _) => AppErrorState(
                message: 'The conversation list could not be read.',
                onRetry: () => ref.invalidate(conversationListProvider),
                bordered: false,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AppEmptyState(
                    title: _search.text.isEmpty
                        ? 'No conversations yet'
                        : 'No matches',
                    description: _search.text.isEmpty
                        ? 'New conversations will appear here as customers '
                              'get in touch.'
                        : 'Nothing on this device matches that search.',
                    icon: LucideIcons.messageSquare,
                    bordered: false,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(conversationListControllerProvider).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TajeerSpacing.xs,
                      vertical: TajeerSpacing.xs2,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final conversation = items[index];

                      return ConversationTile(
                        conversation: conversation,
                        onTap: () => _open(conversation),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The synchronisation notice.
///
/// Reports *synchronisation*, not connection. "Offline" here means the data on
/// screen is known to be behind -- which is a different, more useful statement
/// than whether a socket happens to be open this instant.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});

  final ConversationSyncState state;

  @override
  Widget build(BuildContext context) {
    if (state.phase == SyncPhase.synchronized && !state.hasQueuedWork) {
      return const SizedBox.shrink();
    }

    final (message, tone) = switch (state.phase) {
      SyncPhase.syncing => ('Updating…', AppStatusTone.neutral),
      SyncPhase.stale => (
        'Showing saved conversations. Reconnecting…',
        AppStatusTone.warning,
      ),
      SyncPhase.failed => (
        state.message ?? 'Could not refresh. Showing saved conversations.',
        AppStatusTone.warning,
      ),
      _ when state.failedMutations > 0 => (
        '${state.failedMutations} message(s) could not be sent',
        AppStatusTone.warning,
      ),
      _ when state.pendingMutations > 0 => (
        'Sending ${state.pendingMutations} message(s)…',
        AppStatusTone.neutral,
      ),
      _ => ('', AppStatusTone.neutral),
    };

    if (message.isEmpty) return const SizedBox.shrink();

    return AppStatusBanner(message: message, tone: tone);
  }
}

/// The loading placeholder, shaped like the rows it stands in for.
class _ConversationListSkeleton extends StatelessWidget {
  const _ConversationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.xs,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            const AppSkeleton.circle(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TajeerSpacing.xs,
                children: const <Widget>[
                  AppSkeleton.text(width: 140),
                  AppSkeleton.text(width: double.infinity),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
