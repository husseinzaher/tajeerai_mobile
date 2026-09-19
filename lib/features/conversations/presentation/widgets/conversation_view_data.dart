import '../../../../app/localization/translations/app_strings.dart';
import '../../../../design_system/design_system.dart';
import '../../application/state/sync_state.dart';
import '../../domain/entities/conversation.dart';

/// A conversation, as the Inbox draws it.
///
/// The one place a [Conversation] becomes an [AppConversationSummary], so the
/// fallbacks — which name a row shows, what an empty thread says — are decided
/// once, in the reader's language, instead of in every row.
extension ConversationPresentation on Conversation {
  AppConversationSummary toSummary(AppStrings strings) =>
      AppConversationSummary(
        id: id,
        // The customer's name, then the thread's subject, then the app's own
        // words. Not `displayName`: its last resort is English, for logs, and a
        // row read in Arabic must not show it.
        title:
            _present(customerName) ??
            _present(subject) ??
            strings.unknownCustomer,
        preview: _present(lastMessagePreview) ?? strings.noMessages,
        // A thread with no messages yet still has a moment it began.
        lastActivityAt: lastMessageAt ?? createdAt,
        unreadCount: unreadCount,
        avatarUrl: _present(customerAvatarUrl),
        isPinned: isPinned,
        isMuted: isMuted,
      );
}

/// The Inbox's synchronisation, as the connection banner draws it.
extension SyncStatePresentation on ConversationSyncState {
  AppConnectionStatus get connectionStatus => switch (phase) {
    SyncPhase.syncing => AppConnectionStatus.syncing,
    SyncPhase.stale => AppConnectionStatus.offline,
    SyncPhase.failed => AppConnectionStatus.failed,
    SyncPhase.idle || SyncPhase.synchronized => AppConnectionStatus.current,
  };

  /// Whether the Inbox is still waiting for its first confirmed server pass.
  ///
  /// The local database emits an empty list immediately, so "loaded and empty"
  /// is not the same as "there are no conversations" until a sync has
  /// succeeded at least once.
  bool get isAwaitingFirstInboxData =>
      syncedAt == null && phase != SyncPhase.failed;
}

String? _present(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
