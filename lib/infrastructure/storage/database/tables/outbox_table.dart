import 'package:drift/drift.dart';

/// How far along a queued mutation is.
enum OutboxStatus {
  /// Written locally, not yet attempted. What an offline write produces.
  pending,

  /// A send is in flight. Guards against two workers picking up one row.
  inFlight,

  /// Acknowledged by the server. Kept briefly so the UI can settle, then
  /// pruned -- see `OutboxDao.pruneCompleted`.
  acknowledged,

  /// Rejected in a way retrying cannot fix, or out of attempts. Surfaced to
  /// the user with a retry action; never silently dropped.
  failed,
}

/// Queued mutations awaiting the server.
///
/// The heart of offline writes: a command is durable *before* it is sent, so
/// the app can be killed between the tap and the acknowledgement without
/// losing what the user did.
///
/// This table is business-agnostic. It stores a command name and an encoded
/// payload, and knows nothing about messages or conversations -- the feature
/// that enqueues a row is the one that knows how to build it.
@DataClassName('OutboxEntryRow')
class OutboxEntries extends Table {
  /// Locally generated. Also the idempotency key sent to the server, which is
  /// what makes a retry after a lost acknowledgement return the original
  /// result instead of creating a duplicate.
  TextColumn get id => text()();

  /// The socket command name, e.g. `message:send`.
  TextColumn get command => text()();

  /// JSON-encoded command payload.
  TextColumn get payload => text()();

  /// What the row belongs to -- a conversation id, say. Lets a feature find
  /// its own pending work without decoding every payload.
  TextColumn get scopeId => text().nullable()();

  TextColumn get status => textEnum<OutboxStatus>().withDefault(
    Constant(OutboxStatus.pending.name),
  )();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// The last failure, for display and diagnostics. Never a raw payload.
  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Earliest time the next attempt may run. Carries the backoff, so a failing
  /// row does not spin.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
