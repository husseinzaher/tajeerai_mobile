import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/application/events/conversation_app_events.dart';
import 'package:TajeerAi/features/conversations/application/state/sync_state.dart';

import '../../../support/fixed_clock.dart';

void main() {
  group('ConversationSyncState', () {
    test('starts idle with nothing queued', () {
      const state = ConversationSyncState();

      expect(state.phase, SyncPhase.idle);
      expect(state.hasQueuedWork, isFalse);
      expect(state.isSyncing, isFalse);
      expect(state.isBehind, isFalse);
    });

    test('reports being behind for stale and failed alike', () {
      // Both mean the data is readable but not current, which is a different
      // statement from "broken".
      expect(
        const ConversationSyncState(phase: SyncPhase.stale).isBehind,
        isTrue,
      );
      expect(
        const ConversationSyncState(phase: SyncPhase.failed).isBehind,
        isTrue,
      );
      expect(
        const ConversationSyncState(phase: SyncPhase.synchronized).isBehind,
        isFalse,
      );
    });

    test('reports queued work from either counter', () {
      expect(
        const ConversationSyncState(pendingMutations: 1).hasQueuedWork,
        isTrue,
      );
      expect(
        const ConversationSyncState(failedMutations: 1).hasQueuedWork,
        isTrue,
      );
    });

    test('copyWith changes only what it is given', () {
      final state = ConversationSyncState(
        phase: SyncPhase.synchronized,
        syncedAt: testEpoch,
        pendingMutations: 2,
      );

      final updated = state.copyWith(pendingMutations: 0);

      expect(updated.pendingMutations, 0);
      expect(updated.phase, SyncPhase.synchronized);
      expect(updated.syncedAt, testEpoch);
    });

    test('copyWith can clear the message explicitly', () {
      const state = ConversationSyncState(
        phase: SyncPhase.failed,
        message: 'Could not refresh.',
      );

      expect(state.copyWith(clearMessage: true).message, isNull);
    });

    test('copyWith keeps the message when not clearing', () {
      const state = ConversationSyncState(message: 'Could not refresh.');

      expect(state.copyWith(pendingMutations: 1).message, 'Could not refresh.');
    });

    test('compares by value so the UI does not rebuild needlessly', () {
      const a = ConversationSyncState(phase: SyncPhase.syncing);
      const b = ConversationSyncState(phase: SyncPhase.syncing);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const ConversationSyncState(phase: SyncPhase.idle)));
    });
  });

  group('application events', () {
    test('a message arrival names its thread and direction', () {
      const event = ConversationMessageArrived(
        conversationId: 'c1',
        isInbound: true,
      );

      expect(event.conversationId, 'c1');
      expect(event.isInbound, isTrue);
    });

    test('a completed sync reports what it wrote', () {
      final event = ConversationSyncCompleted(
        syncedAt: testEpoch,
        conversationsWritten: 3,
        messagesWritten: 12,
      );

      expect(event.conversationsWritten, 3);
      expect(event.messagesWritten, 12);
      expect(event.syncedAt, testEpoch);
    });

    test('a failed mutation carries a non-sensitive reason', () {
      const event = ConversationMutationFailed(
        outboxId: 'client-1',
        reason: 'VALIDATION_FAILED',
      );

      // Never a message body -- these reach logs.
      expect(event.reason, 'VALIDATION_FAILED');
      expect(event.outboxId, 'client-1');
    });

    test('the event hierarchy is exhaustive', () {
      String describe(ConversationAppEvent event) => switch (event) {
        ConversationMessageArrived() => 'arrived',
        ConversationSyncCompleted() => 'synced',
        ConversationMutationFailed() => 'failed',
      };

      expect(
        describe(
          const ConversationMessageArrived(
            conversationId: 'c1',
            isInbound: false,
          ),
        ),
        'arrived',
      );
    });
  });
}
