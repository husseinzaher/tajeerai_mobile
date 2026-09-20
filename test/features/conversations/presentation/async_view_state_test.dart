import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/design_system/feedback/async_view.dart';
import 'package:TajeerAi/features/conversations/application/state/sync_state.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/presentation/widgets/conversation_view_data.dart';
import 'package:TajeerAi/features/conversations/presentation/widgets/async_view_state.dart';

import '../../../support/fixed_clock.dart';

void main() {
  test('nothing yet is loading', () {
    expect(
      const AsyncLoading<int>().toViewState(
        (int value) => '$value',
        failure: 'unused',
      ),
      isA<AppViewLoading<String>>(),
    );
  });

  test('a value is loaded, mapped into what the screen draws', () {
    final AppViewState<int> state = const AsyncData<int>(2)
        .toViewState((int value) => value * 2, failure: 'unused');

    expect(state, isA<AppViewLoaded<int>>());
    expect((state as AppViewLoaded<int>).value, 4);
  });

  test('a failure with nothing to show carries the app\'s words and retry', () {
    int retried = 0;
    final AppViewState<int> state =
        AsyncError<int>(
          StateError('the database is locked'),
          StackTrace.empty,
        ).toViewState(
          (int value) => value,
          failure: 'The list could not be read.',
          onRetry: () => retried++,
        );

    expect(state, isA<AppViewFailed<int>>());
    final AppViewFailed<int> failure = state as AppViewFailed<int>;
    // The copy the app chose, never the exception's own text.
    expect(failure.message, 'The list could not be read.');
    failure.onRetry!();
    expect(retried, 1);
  });

  test('rows stay on screen while a refresh runs', () async {
    int reads = 0;
    final FutureProvider<int> answer = FutureProvider<int>(
      (Ref ref) async => ++reads,
    );
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(
      answer,
      (AsyncValue<int>? previous, AsyncValue<int> next) {},
    );

    await container.read(answer.future);
    container.invalidate(answer);
    final AsyncValue<int> refreshing = container.read(answer);

    expect(refreshing.isLoading, isTrue);
    expect(
      refreshing.toViewState((int value) => value, failure: 'unused'),
      isA<AppViewLoaded<int>>(),
    );
  });

  test('and after a refresh fails', () async {
    final StreamController<int> source = StreamController<int>();
    addTearDown(source.close);
    final StreamProvider<int> numbers = StreamProvider<int>(
      (Ref ref) => source.stream,
    );
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(
      numbers,
      (AsyncValue<int>? previous, AsyncValue<int> next) {},
    );

    source.add(7);
    await Future<void>.delayed(Duration.zero);
    source.addError(StateError('the socket dropped'));
    await Future<void>.delayed(Duration.zero);
    final AsyncValue<int> failed = container.read(numbers);

    expect(failed.hasError, isTrue);
    final AppViewState<int> state = failed.toViewState(
      (int value) => value,
      failure: 'unused',
    );
    expect(state, isA<AppViewLoaded<int>>());
    expect((state as AppViewLoaded<int>).value, 7);
  });

  test('an empty local inbox before the first sync is loading', () {
    const AsyncData<List<Conversation>> empty = AsyncData<List<Conversation>>(
      <Conversation>[],
    );

    expect(
      empty.toInboxViewState(
        (List<Conversation> items) => items.length,
        sync: const ConversationSyncState(phase: SyncPhase.syncing),
        searching: false,
        failure: 'unused',
      ),
      isA<AppViewLoading<int>>(),
    );
  });

  /// The endless skeleton.
  ///
  /// A first sync that fails and is then overtaken by the connection dropping
  /// lands in `stale`, not `failed` -- and reading the phase alone left the
  /// rail claiming it was still waiting for its first pass. On a real device
  /// that was an Inbox of placeholder rows that never resolved, with the
  /// connection banner suppressed behind the same flag, so nothing on screen
  /// said anything had gone wrong or offered a retry.
  test(
    'a first sync that failed is not still awaiting, whatever the phase',
    () {
      const AsyncData<List<Conversation>> empty = AsyncData<List<Conversation>>(
        <Conversation>[],
      );

      final AppViewState<int> state = empty.toInboxViewState(
        (List<Conversation> items) => items.length,
        sync: const ConversationSyncState(
          // Where `_markStale` leaves it after the failure.
          phase: SyncPhase.stale,
          hasFailedAttempt: true,
        ),
        searching: false,
        failure: 'unused',
      );

      expect(state, isA<AppViewLoaded<int>>());
    },
  );

  test('a failed first sync is still not awaiting once it goes stale', () {
    const ConversationSyncState failedThenStale = ConversationSyncState(
      phase: SyncPhase.stale,
      hasFailedAttempt: true,
    );

    expect(failedThenStale.isAwaitingFirstInboxData, isFalse);

    // And a pass that has simply not run yet still is.
    const ConversationSyncState fresh = ConversationSyncState(
      phase: SyncPhase.stale,
    );

    expect(fresh.isAwaitingFirstInboxData, isTrue);
  });

  test('an empty inbox after a confirmed sync is loaded', () {
    const AsyncData<List<Conversation>> empty = AsyncData<List<Conversation>>(
      <Conversation>[],
    );

    final AppViewState<int> state = empty.toInboxViewState(
      (List<Conversation> items) => items.length,
      sync: ConversationSyncState(
        phase: SyncPhase.synchronized,
        syncedAt: testEpoch,
      ),
      searching: false,
      failure: 'unused',
    );

    expect(state, isA<AppViewLoaded<int>>());
    expect((state as AppViewLoaded<int>).value, 0);
  });
}
