import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../application/state/sync_state.dart';
import '../../domain/entities/conversation.dart';
import 'conversation_view_data.dart';

/// Riverpod's [AsyncValue], as a state the design system draws.
///
/// Here and not in the design system, which may not know Riverpod exists
/// (RULE 33).
///
/// **A value beats a spinner.** The Inbox reads the local database, so a value
/// that is there stays on screen while a refresh runs and after one fails. Only
/// a failure with nothing to show is drawn as a failure.
extension AsyncValueView<T> on AsyncValue<T> {
  AppViewState<R> toViewState<R>(
    R Function(T value) map, {
    required String failure,
    VoidCallback? onRetry,
  }) {
    if (hasValue) {
      return AppViewLoaded<R>(map(requireValue));
    }
    if (hasError) {
      return AppViewFailed<R>(failure, onRetry: onRetry);
    }
    return AppViewLoading<R>();
  }
}

/// The Inbox rail's [AsyncValue], as a state the design system draws.
///
/// The database answers with an empty list before the first server pass
/// finishes, so an empty local read during [ConversationSyncState.isAwaitingFirstInboxData]
/// is drawn as loading — placeholder rows — rather than an empty Inbox or a
/// retry surface.
extension InboxListView on AsyncValue<List<Conversation>> {
  AppViewState<R> toInboxViewState<R>(
    R Function(List<Conversation> value) map, {
    required ConversationSyncState? sync,
    required bool searching,
    required String failure,
    VoidCallback? onRetry,
  }) {
    if (searching) {
      return toViewState(map, failure: failure, onRetry: onRetry);
    }

    final bool awaitingFirstInbox = sync?.isAwaitingFirstInboxData ?? true;

    if (awaitingFirstInbox && hasValue && requireValue.isEmpty) {
      return AppViewLoading<R>();
    }

    return toViewState(map, failure: failure, onRetry: onRetry);
  }
}
