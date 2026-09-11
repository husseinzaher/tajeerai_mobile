import 'package:drift/drift.dart';

/// Per-scope synchronisation bookkeeping.
///
/// Separate from connection state on purpose. A socket being open says nothing
/// about whether this client has caught up, and the two answer different
/// questions for the UI: "are we live" versus "is what you are reading
/// current".
///
/// One row per synchronisation scope -- the conversation list, one thread's
/// messages -- so a stale thread does not make the whole app look stale.
@DataClassName('SyncStateRow')
class SyncStates extends Table {
  /// The scope key, e.g. `conversations` or `messages:<conversationId>`.
  TextColumn get scope => text()();

  /// The `since` cursor for the next incremental sync.
  ///
  /// The backend's `conversation:sync` takes an ISO timestamp and returns
  /// everything changed after it, so the cursor is a time rather than a
  /// sequence number.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Where a sync over one of the paged HTTP lists resumes.
  ///
  /// Those lists are numbered pages with no server cursor, and a page number
  /// alone drifts as rows are added or changed mid-walk. So each scope's
  /// syncer stores what it needs to carry on without skipping a row, in its
  /// own form -- opaque to this table. Null for the scopes the socket syncs,
  /// which resume from [syncedAt].
  TextColumn get pageCursor => text().nullable()();

  TextColumn get status =>
      textEnum<SyncStatus>().withDefault(Constant(SyncStatus.idle.name))();

  /// When the last attempt finished, successfully or not. Drives "last updated
  /// N minutes ago" and the staleness check.
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{scope};
}

/// Synchronisation state, tracked independently of the connection.
enum SyncStatus {
  /// Nothing in flight. Says nothing about freshness -- check `syncedAt`.
  idle,

  syncing,

  /// Caught up as of `syncedAt`.
  synchronized,

  /// Readable but known to be behind: the client was offline, or a sync failed
  /// and the data on screen predates it.
  stale,

  /// The last attempt failed. Data stays readable; this is not an empty state.
  failed,
}

/// Events already applied, so replays are no-ops.
///
/// The backend puts `eventId` on every broadcast precisely because a reconnect
/// can redeliver a fact the client already holds. Without this table, applying
/// `conversation.unread-updated` twice double-counts.
///
/// Pruned by age -- see `SyncDao.pruneProcessedEvents` -- because it would
/// otherwise grow without bound.
@DataClassName('ProcessedEventRow')
class ProcessedEvents extends Table {
  TextColumn get eventId => text()();

  /// The event name, for diagnostics only.
  TextColumn get eventName => text()();

  DateTimeColumn get processedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{eventId};
}
