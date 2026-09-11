import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_state_table.dart';

part 'sync_dao.g.dart';

/// Row access for synchronisation metadata and event deduplication.
///
/// Storage only: it records that an event was applied, and never decides what
/// applying one means.
@DriftAccessor(tables: <Type>[SyncStates, ProcessedEvents])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.database);

  Future<SyncStateRow?> stateOf(String scope) {
    return (select(
      syncStates,
    )..where((row) => row.scope.equals(scope))).getSingleOrNull();
  }

  Stream<SyncStateRow?> watchState(String scope) {
    return (select(
      syncStates,
    )..where((row) => row.scope.equals(scope))).watchSingleOrNull();
  }

  /// The `since` cursor for the next incremental sync, or null when this scope
  /// has never synced and needs a full first pass.
  Future<DateTime?> cursorFor(String scope) async =>
      (await stateOf(scope))?.syncedAt;

  /// Where a paged HTTP sync of [scope] resumes, or null when it has nothing
  /// to resume. See `SyncStates.pageCursor`.
  Future<String?> pageCursorFor(String scope) async =>
      (await stateOf(scope))?.pageCursor;

  /// Stores where a paged HTTP sync of [scope] resumes, or clears it with
  /// null once there is nothing left to carry on.
  ///
  /// Call it inside the transaction that writes the page it follows: a process
  /// killed mid-walk then resumes after the last page that actually landed,
  /// never after one that did not. Nothing else about the scope changes.
  Future<void> savePageCursor(String scope, String? cursor) async {
    await into(syncStates).insert(
      SyncStatesCompanion.insert(
        scope: scope,
        pageCursor: Value<String?>(cursor),
      ),
      onConflict: DoUpdate(
        (_) => SyncStatesCompanion(pageCursor: Value<String?>(cursor)),
      ),
    );
  }

  Future<void> markSyncing(String scope, {required DateTime now}) async {
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        scope: scope,
        status: Value<SyncStatus>(SyncStatus.syncing),
        lastAttemptAt: Value<DateTime?>(now),
        // The existing cursor is deliberately not written here: a sync that
        // fails must leave the previous cursor intact, or the client silently
        // skips the window it never received.
        syncedAt: Value<DateTime?>(await cursorFor(scope)),
      ),
    );
  }

  /// Records a successful sync and advances the cursor.
  ///
  /// [syncedAt] is the server's own `syncedAt` from the acknowledgement, never
  /// the device clock: a phone whose clock is minutes fast would otherwise
  /// skip every change in that window.
  Future<void> markSynchronized(
    String scope, {
    required DateTime syncedAt,
    required DateTime now,
  }) async {
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        scope: scope,
        status: const Value<SyncStatus>(SyncStatus.synchronized),
        syncedAt: Value<DateTime?>(syncedAt),
        lastAttemptAt: Value<DateTime?>(now),
        lastError: const Value<String?>(null),
      ),
    );
  }

  /// Records a failure without touching the cursor, so the next attempt
  /// re-requests the same window.
  Future<void> markFailed(
    String scope, {
    required DateTime now,
    String? error,
  }) async {
    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        scope: scope,
        status: const Value<SyncStatus>(SyncStatus.failed),
        syncedAt: Value<DateTime?>(await cursorFor(scope)),
        lastAttemptAt: Value<DateTime?>(now),
        lastError: Value<String?>(error),
      ),
    );
  }

  /// Flags a scope as known-behind -- on going offline, or on reconnecting
  /// before the catch-up has run. The data stays readable; only its freshness
  /// is in question.
  Future<void> markStale(String scope) async {
    final existing = await stateOf(scope);

    await into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        scope: scope,
        status: const Value<SyncStatus>(SyncStatus.stale),
        syncedAt: Value<DateTime?>(existing?.syncedAt),
        lastAttemptAt: Value<DateTime?>(existing?.lastAttemptAt),
      ),
    );
  }

  /// Records an event as applied, and reports whether it is new.
  ///
  /// Returns false when the id was already present, which is the caller's
  /// signal to skip it. `insertOrIgnore` makes the check and the claim one
  /// statement, so two frames racing cannot both be told they are first.
  ///
  /// `insertReturningOrNull` rather than `insert`: the latter returns a rowid,
  /// and on an *ignored* insert SQLite leaves `last_insert_rowid()` at its
  /// previous value -- so a duplicate came back as a positive number and was
  /// reported as new. That defeated deduplication entirely, and every replayed
  /// event was applied twice. Returning null on conflict is unambiguous.
  Future<bool> registerEvent({
    required String eventId,
    required String eventName,
    required DateTime now,
  }) async {
    final inserted = await into(processedEvents).insertReturningOrNull(
      ProcessedEventsCompanion.insert(
        eventId: eventId,
        eventName: eventName,
        processedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );

    return inserted != null;
  }

  Future<bool> hasProcessed(String eventId) async {
    final row = await (select(
      processedEvents,
    )..where((event) => event.eventId.equals(eventId))).getSingleOrNull();

    return row != null;
  }

  /// Drops deduplication records older than [before].
  ///
  /// Bounded on purpose: the table would otherwise grow forever. The window
  /// only has to outlast the longest plausible replay, which is a reconnect,
  /// not a week.
  Future<int> pruneProcessedEvents({required DateTime before}) {
    return (delete(
      processedEvents,
    )..where((row) => row.processedAt.isSmallerThanValue(before))).go();
  }
}
