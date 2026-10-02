import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

/// Row access for the outbox.
///
/// Storage only. It decides nothing about *whether* a mutation should be
/// retried or what it means -- that is the coordinator's job. What it does own
/// is the atomicity that makes the queue safe: claiming a row and marking it
/// in-flight has to be one statement, or two drains can send the same command
/// twice.
@DriftAccessor(tables: <Type>[OutboxEntries])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.database);

  /// Enqueues a mutation. [id] doubles as the server-facing idempotency key.
  Future<void> enqueue({
    required String id,
    required String command,
    required String payload,
    String? scopeId,
    required DateTime now,
  }) {
    return into(outboxEntries).insert(
      OutboxEntriesCompanion.insert(
        id: id,
        command: command,
        payload: payload,
        scopeId: Value<String?>(scopeId),
        createdAt: now,
        updatedAt: now,
        nextAttemptAt: Value<DateTime?>(now),
      ),
      // A re-enqueue of the same id is the same intent, not a second one.
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Rows due to be sent, oldest first.
  ///
  /// Excludes rows already in flight and rows whose backoff has not elapsed,
  /// so a caller can drain what it is handed without re-filtering.
  Future<List<OutboxEntryRow>> due({required DateTime now, int limit = 20}) {
    return (select(outboxEntries)
          ..where((row) => row.status.equalsValue(OutboxStatus.pending))
          ..where(
            (row) =>
                row.nextAttemptAt.isSmallerOrEqualValue(now) |
                row.nextAttemptAt.isNull(),
          )
          ..orderBy(<OrderClauseGenerator<$OutboxEntriesTable>>[
            (row) => OrderingTerm.asc(row.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  /// Atomically claims a pending row for sending.
  ///
  /// Returns false when another drain got there first. The `status = pending`
  /// predicate is the lock: two concurrent claims cannot both match, so a
  /// command is never sent twice from two workers.
  Future<bool> claim(String id, {required DateTime now}) async {
    final updated =
        await (update(outboxEntries)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.status.equalsValue(OutboxStatus.pending)))
            .write(
              OutboxEntriesCompanion(
                status: Value<OutboxStatus>(OutboxStatus.inFlight),
                attempts: Value<int>(await _attemptsOf(id) + 1),
                updatedAt: Value<DateTime>(now),
              ),
            );

    return updated > 0;
  }

  Future<int> _attemptsOf(String id) async {
    final row = await (select(
      outboxEntries,
    )..where((r) => r.id.equals(id))).getSingleOrNull();

    return row?.attempts ?? 0;
  }

  /// Marks a row acknowledged by the server.
  Future<void> markAcknowledged(String id, {required DateTime now}) {
    return (update(outboxEntries)..where((row) => row.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: const Value<OutboxStatus>(OutboxStatus.acknowledged),
        lastError: const Value<String?>(null),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Returns a row to `pending` with a later [nextAttemptAt].
  ///
  /// For retryable failures only. The caller computes the backoff, because how
  /// long to wait is a policy decision and this is storage.
  Future<void> scheduleRetry(
    String id, {
    required DateTime nextAttemptAt,
    required DateTime now,
    String? error,
  }) {
    return (update(outboxEntries)..where((row) => row.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: const Value<OutboxStatus>(OutboxStatus.pending),
        nextAttemptAt: Value<DateTime?>(nextAttemptAt),
        lastError: Value<String?>(error),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Marks a row permanently failed. Stays in the table so the UI can offer a
  /// manual retry -- a dropped mutation the user never hears about is worse
  /// than a visible failure.
  Future<void> markFailed(String id, {required DateTime now, String? error}) {
    return (update(outboxEntries)..where((row) => row.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: const Value<OutboxStatus>(OutboxStatus.failed),
        lastError: Value<String?>(error),
        nextAttemptAt: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Returns a failed row to the queue for a user-initiated retry, clearing
  /// the attempt count so it is not immediately failed again by the cap.
  Future<void> resetForRetry(String id, {required DateTime now}) {
    return (update(outboxEntries)..where((row) => row.id.equals(id))).write(
      OutboxEntriesCompanion(
        status: const Value<OutboxStatus>(OutboxStatus.pending),
        attempts: const Value<int>(0),
        lastError: const Value<String?>(null),
        nextAttemptAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  Future<OutboxEntryRow?> find(String id) {
    return (select(
      outboxEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  /// Rows a feature still owes the server, for a scope.
  Stream<List<OutboxEntryRow>> watchUnsettled({String? scopeId}) {
    final query = select(outboxEntries)
      ..where(
        (row) =>
            row.status.equalsValue(OutboxStatus.pending) |
            row.status.equalsValue(OutboxStatus.inFlight) |
            row.status.equalsValue(OutboxStatus.failed),
      );

    if (scopeId != null) {
      query.where((row) => row.scopeId.equals(scopeId));
    }

    return query.watch();
  }

  /// Returns in-flight rows to `pending` at start-up.
  ///
  /// A row left in-flight means the process died mid-send. The command may or
  /// may not have reached the server, which is exactly the case the
  /// idempotency key covers, so retrying is safe and dropping it is not.
  Future<int> recoverInFlight({required DateTime now}) {
    return (update(
      outboxEntries,
    )..where((row) => row.status.equalsValue(OutboxStatus.inFlight))).write(
      OutboxEntriesCompanion(
        status: const Value<OutboxStatus>(OutboxStatus.pending),
        nextAttemptAt: Value<DateTime?>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// Drops acknowledged rows older than [before]. Keeps the table bounded.
  Future<int> pruneCompleted({required DateTime before}) {
    return (delete(outboxEntries)
          ..where((row) => row.status.equalsValue(OutboxStatus.acknowledged))
          ..where((row) => row.updatedAt.isSmallerThanValue(before)))
        .go();
  }

  Future<void> remove(String id) {
    return (delete(outboxEntries)..where((row) => row.id.equals(id))).go();
  }
}
