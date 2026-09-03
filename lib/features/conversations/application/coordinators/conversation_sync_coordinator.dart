import 'dart:async';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/daos/sync_dao.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../../../infrastructure/realtime/connection/connection_state.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../events/conversation_app_events.dart';
import '../state/sync_state.dart';
import 'outbox_coordinator.dart';

/// Keeps local state caught up with the server.
///
/// **The read half of the offline architecture**, and the piece that makes
/// "reconnected" mean something. A socket coming back does not make this
/// client current -- events delivered while it was closed are simply gone, and
/// a dropped connection looks identical to a quiet one. This runs the
/// catch-up that closes that gap.
///
/// Three entry points, in order of how much they do:
///
/// - [performInitialSync] -- the first run on a device, or after sign-in.
///   There is no cursor, so it pulls a page of the rail.
/// - [performIncrementalSync] -- everything changed since the stored cursor,
///   via the backend's `conversation:sync`.
/// - [onReconnected] -- what runs on every (re)connection: catch up, then
///   drain whatever the outbox accumulated while offline.
///
/// The cursor is only advanced on a *confirmed* success, using the server's
/// own `syncedAt`. A failed pass leaves it alone so the next attempt asks for
/// the same window again -- advancing past an unconfirmed window is how a
/// client silently skips a day of messages.
class ConversationSyncCoordinator {
  ConversationSyncCoordinator({
    required ConversationRepository conversations,
    required SyncDao syncDao,
    required OutboxCoordinator outbox,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
  }) : _conversations = conversations,
       _syncDao = syncDao,
       _outbox = outbox,
       _logger = logger,
       _clock = clock;

  final ConversationRepository _conversations;
  final SyncDao _syncDao;
  final OutboxCoordinator _outbox;
  final Logger _logger;
  final DateTime Function() _clock;

  /// The synchronisation scope for the rail.
  static const String inboxScope = 'conversations';

  /// How far back a first sync reaches when there is no cursor.
  static const Duration initialWindow = Duration(days: 30);

  final StreamController<ConversationSyncState> _states =
      StreamController<ConversationSyncState>.broadcast();
  final StreamController<ConversationAppEvent> _events =
      StreamController<ConversationAppEvent>.broadcast();

  ConversationSyncState _state = const ConversationSyncState();

  ConversationSyncState get state => _state;

  Stream<ConversationSyncState> get states => _states.stream;

  Stream<ConversationAppEvent> get events => _events.stream;

  StreamSubscription<void>? _connectionSubscription;
  StreamSubscription<SocketConnectionState>? _stateSubscription;

  bool _syncing = false;

  /// Wires the coordinator to the connection's lifecycle.
  ///
  /// [connections] fires on every successful (re)connection -- that is the
  /// catch-up trigger. [connectionStates] is watched separately so going
  /// offline can mark the scope stale immediately, rather than letting the UI
  /// keep claiming it is current.
  void bindTo({
    required Stream<void> connections,
    required Stream<SocketConnectionState> connectionStates,
  }) {
    _connectionSubscription ??= connections.listen(
      (_) => unawaited(onReconnected()),
    );

    _stateSubscription ??= connectionStates.listen((state) {
      if (state.isConnected) return;

      // Not a failure -- the data is still valid, it is just no longer
      // guaranteed current.
      unawaited(_markStale());
    });
  }

  /// Runs after every successful connection.
  ///
  /// Catch-up first, then the outbox: applying the server's view before
  /// replaying local writes means a message that was already accepted (but
  /// whose acknowledgement was lost) is reconciled by the sync rather than
  /// re-sent blindly. The idempotency key would have caught it either way;
  /// this order simply avoids the round trip.
  Future<void> onReconnected() async {
    await synchronize();
    await _outbox.recoverInterrupted();
    await _outbox.drain();
  }

  /// Runs the right kind of sync for the stored cursor.
  Future<void> synchronize() async {
    final cursor = await _syncDao.cursorFor(inboxScope);

    if (cursor == null) {
      await performInitialSync();

      return;
    }

    await performIncrementalSync(cursor);
  }

  /// The first pass on a device.
  ///
  /// Pulls a page of the rail rather than asking for changes since a cursor
  /// that does not exist. The messages for a thread arrive when it is opened;
  /// pre-fetching every message in every conversation would be a large
  /// download for data most of which is never read.
  Future<int> performInitialSync({int limit = 25}) async {
    if (_syncing) return 0;

    _syncing = true;
    await _enterSyncing();

    try {
      final written = await _conversations.synchronizeList(limit: limit);
      final now = _clock().toUtc();

      await _syncDao.markSynchronized(inboxScope, syncedAt: now, now: now);

      _publish(
        _state.copyWith(
          phase: SyncPhase.synchronized,
          syncedAt: now,
          clearMessage: true,
        ),
      );

      _announce(
        ConversationSyncCompleted(
          syncedAt: now,
          conversationsWritten: written,
          messagesWritten: 0,
        ),
      );

      return written;
    } on Object catch (error) {
      await _recordFailure(error);

      return 0;
    } finally {
      _syncing = false;
    }
  }

  /// Everything changed since [since].
  ///
  /// Maps to `conversation:sync`, which returns the current state of affected
  /// rows rather than an event replay -- smaller after a long absence, and
  /// immune to being applied out of order.
  Future<SyncOutcome?> performIncrementalSync(
    DateTime since, {
    String? conversationId,
  }) async {
    if (_syncing) return null;

    _syncing = true;
    await _enterSyncing();

    try {
      final outcome = await _conversations.synchronizeSince(
        since,
        conversationId: conversationId,
      );

      await _syncDao.markSynchronized(
        inboxScope,
        // The server's stamp, never the device clock: a phone running fast
        // would skip the window between the two.
        syncedAt: outcome.syncedAt,
        now: _clock().toUtc(),
      );

      _publish(
        _state.copyWith(
          phase: SyncPhase.synchronized,
          syncedAt: outcome.syncedAt,
          clearMessage: true,
        ),
      );

      _announce(
        ConversationSyncCompleted(
          syncedAt: outcome.syncedAt,
          conversationsWritten: outcome.conversationsWritten,
          messagesWritten: outcome.messagesWritten,
        ),
      );

      return outcome;
    } on Object catch (error) {
      await _recordFailure(error);

      return null;
    } finally {
      _syncing = false;
    }
  }

  /// Keeps the queued/failed counts on the published state current.
  void trackOutbox() {
    _outbox.watchSummary().listen((summary) {
      _publish(
        _state.copyWith(
          pendingMutations: summary.pending,
          failedMutations: summary.failed,
        ),
      );
    });
  }

  Future<void> _enterSyncing() async {
    await _syncDao.markSyncing(inboxScope, now: _clock().toUtc());
    _publish(_state.copyWith(phase: SyncPhase.syncing, clearMessage: true));
  }

  Future<void> _markStale() async {
    await _syncDao.markStale(inboxScope);
    _publish(_state.copyWith(phase: SyncPhase.stale));
  }

  /// Records a failed pass without touching the cursor.
  Future<void> _recordFailure(Object error) async {
    final failure = error is AppFailure
        ? error
        : SynchronizationFailure(
            message: 'Could not refresh conversations.',
            cause: error,
          );

    _logger.warning(
      'sync failed',
      data: <String, Object?>{'failure': failure.runtimeType.toString()},
    );

    await _syncDao.markFailed(
      inboxScope,
      now: _clock().toUtc(),
      error: failure.runtimeType.toString(),
    );

    _publish(
      _state.copyWith(phase: SyncPhase.failed, message: failure.message),
    );
  }

  void _publish(ConversationSyncState next) {
    if (_state == next) return;

    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _announce(ConversationAppEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> dispose() async {
    await _connectionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _states.close();
    await _events.close();
  }
}
