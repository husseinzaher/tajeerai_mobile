import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/app_database.dart';
import '../../../../infrastructure/database/daos/outbox_dao.dart';
import '../../../../infrastructure/database/tables/outbox_table.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../data/remote/conversation_remote_data_source.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../../realtime/conversation_events.dart';
import '../events/conversation_app_events.dart';

/// Drains the outbox.
///
/// **The write half of the offline architecture.** A message is durable before
/// this runs -- `MessageRepositoryImpl.enqueueOutbound` writes the row and the
/// queue entry in one transaction -- so this coordinator's only job is getting
/// what is already queued to the server, and reconciling what comes back.
///
/// The sequence, per entry:
///
/// 1. claim it atomically, so two drains cannot send it twice;
/// 2. dispatch the socket command with the entry's id as the idempotency key;
/// 3. on acknowledgement, re-key the optimistic row to the server's id;
/// 4. on a retryable failure, back off and requeue;
/// 5. on a permanent rejection or the attempt cap, mark it failed and leave it
///    visible so the user can retry by hand.
///
/// It orchestrates; it decides no business rules. Whether a message *may* be
/// sent was settled by `MessageService.compose` before the row existed.
class OutboxCoordinator {
  OutboxCoordinator({
    required AppDatabase database,
    required OutboxDao outbox,
    required MessageRepository messages,
    required ConversationRemoteDataSource remote,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
    Random? random,
  }) : _database = database,
       _outbox = outbox,
       _messages = messages,
       _remote = remote,
       _logger = logger,
       _clock = clock,
       _random = random ?? Random();

  final AppDatabase _database;
  final OutboxDao _outbox;
  final MessageRepository _messages;
  final ConversationRemoteDataSource _remote;
  final Logger _logger;
  final DateTime Function() _clock;
  final Random _random;

  /// After this many attempts an entry stops retrying on its own.
  ///
  /// Bounded so a permanently broken command does not retry forever on a
  /// user's battery. The row stays visible and manually retryable, which is
  /// the difference between giving up and losing the message.
  static const int maxAttempts = 5;

  final StreamController<ConversationAppEvent> _events =
      StreamController<ConversationAppEvent>.broadcast();

  Stream<ConversationAppEvent> get events => _events.stream;

  bool _draining = false;

  /// Returns entries stuck in-flight to the queue, and the messages with them.
  ///
  /// Run once at start-up. An in-flight row means the process died mid-send:
  /// the command may or may not have reached the server, which is precisely
  /// what the idempotency key covers, so retrying is safe and dropping is not.
  ///
  /// Resetting the *message* alongside the entry matters for what the user
  /// sees. `_sendMessage` moves the row to `sending` before dispatching, and a
  /// process that dies mid-flight leaves it there -- so the bubble reads
  /// "Sending" forever while the queue has quietly gone back to `pending`.
  /// Observed on a real device: two messages stuck on "Sending" with nothing
  /// in flight behind them.
  Future<int> recoverInterrupted() async {
    final entries = await _outbox.watchUnsettled().first;
    final recovered = await _outbox.recoverInFlight(now: _clock().toUtc());

    for (final entry in entries) {
      if (entry.status != OutboxStatus.inFlight) continue;

      await _markMessageState(entry, MessageState.pending, null);
    }

    return recovered;
  }

  /// Sends everything currently due.
  ///
  /// Guarded against re-entry: a reconnect and a timer can fire together, and
  /// two concurrent drains would race for the same rows. Returns how many
  /// entries were acknowledged.
  Future<int> drain({int batchSize = 20}) async {
    if (_draining) return 0;

    _draining = true;

    try {
      final now = _clock().toUtc();
      final due = await _outbox.due(now: now, limit: batchSize);

      var acknowledged = 0;

      for (final entry in due) {
        if (await _dispatch(entry)) acknowledged += 1;
      }

      return acknowledged;
    } finally {
      _draining = false;
    }
  }

  Future<bool> _dispatch(OutboxEntryRow entry) async {
    final now = _clock().toUtc();

    // The claim is the lock. A false return means another drain took it.
    if (!await _outbox.claim(entry.id, now: now)) return false;

    // The attempt count was incremented by the claim, so read it back rather
    // than using the stale value from the row we were handed.
    final attempts = (await _outbox.find(entry.id))?.attempts ?? entry.attempts;

    try {
      await _execute(entry);
      await _outbox.markAcknowledged(entry.id, now: _clock().toUtc());

      return true;
    } on SocketFailure catch (failure) {
      // `isRetryable` and `code` travel on the failure, so the queue decides
      // backoff-versus-give-up without knowing a socket exists.
      await _handleFailure(entry, attempts, failure.isRetryable, failure.code);

      return false;
    } on ValidationFailure {
      // The server will reject the identical command again.
      await _handleFailure(entry, attempts, false, 'VALIDATION_FAILED');

      return false;
    } on ConflictFailure {
      await _handleFailure(entry, attempts, false, 'CONFLICT');

      return false;
    } on AuthorizationFailure {
      await _handleFailure(entry, attempts, false, 'FORBIDDEN');

      return false;
    } on NotFoundFailure {
      await _handleFailure(entry, attempts, false, 'NOT_FOUND');

      return false;
    } on AuthenticationFailure {
      // Retryable: the socket layer refreshes the session and reconnects, and
      // this entry should go out once it does.
      await _handleFailure(entry, attempts, true, 'UNAUTHENTICATED');

      return false;
    } on FormatException {
      // The server answered something this client cannot read. Retrying will
      // produce the same unreadable answer, so it is terminal.
      await _handleFailure(entry, attempts, false, 'MALFORMED_ACK');

      return false;
    } on Object catch (error, stackTrace) {
      _logger.error(
        'outbox dispatch failed',
        error: error,
        stackTrace: stackTrace,
        data: <String, Object?>{'command': entry.command},
      );

      await _handleFailure(entry, attempts, true, 'UNKNOWN');

      return false;
    }
  }

  /// Runs one queued command.
  ///
  /// A `switch` on the command name rather than a registry: there are three,
  /// and an unknown one has to be a visible failure rather than a silent skip
  /// that leaves the row queued forever.
  Future<void> _execute(OutboxEntryRow entry) async {
    final payload = _decodePayload(entry.payload);

    switch (entry.command) {
      case ConversationCommands.messageSend:
        await _sendMessage(entry, payload);

      case ConversationCommands.read:
        final conversationId = payload['conversationId']?.toString();

        if (conversationId == null) {
          throw const FormatException('read entry carried no conversation.');
        }

        await _remote.markRead(conversationId);

      default:
        throw ValidationFailure(
          message: 'Unsupported queued command "${entry.command}".',
        );
    }
  }

  /// Sends a queued message and reconciles the optimistic row.
  ///
  /// The row is moved to `sending` first so the UI shows the change while the
  /// command is in flight, then re-keyed to the server's id on
  /// acknowledgement. `deduplicated: true` is treated exactly like a fresh
  /// success -- it means an earlier attempt already landed, which is the
  /// idempotency key doing its job, not an error.
  Future<void> _sendMessage(
    OutboxEntryRow entry,
    Map<String, Object?> payload,
  ) async {
    final conversationId = payload['conversationId']?.toString();
    final body = payload['body']?.toString();
    final clientMessageId = payload['clientMessageId']?.toString() ?? entry.id;

    if (conversationId == null || body == null) {
      throw const FormatException('send entry was incomplete.');
    }

    await _messages.updateState(
      messageId: clientMessageId,
      state: MessageState.sending,
    );

    final result = await _remote.sendMessage(
      conversationId: conversationId,
      body: body,
      clientMessageId: clientMessageId,
    );

    await _messages.reconcile(
      clientMessageId: clientMessageId,
      serverMessageId: result.messageId,
      state: MessageState.sent,
    );

    if (result.deduplicated) {
      _logger.debug('send was deduplicated server-side');
    }

    _announce(
      ConversationMessageArrived(
        conversationId: conversationId,
        isInbound: false,
      ),
    );
  }

  /// Requeues with backoff, or gives up.
  Future<void> _handleFailure(
    OutboxEntryRow entry,
    int attempts,
    bool retryable,
    String? code,
  ) async {
    final now = _clock().toUtc();
    final exhausted = attempts >= maxAttempts;

    if (retryable && !exhausted) {
      await _outbox.scheduleRetry(
        entry.id,
        nextAttemptAt: now.add(_backoff(attempts)),
        now: now,
        error: code,
      );

      // Back to `pending`, not `failed`: it is still going to be sent, and
      // showing a failure the app is about to retry teaches the user to
      // distrust the indicator.
      await _markMessageState(entry, MessageState.pending, null);

      return;
    }

    await _outbox.markFailed(entry.id, now: now, error: code);
    await _markMessageState(entry, MessageState.failed, code);

    _announce(
      ConversationMutationFailed(outboxId: entry.id, reason: code ?? 'UNKNOWN'),
    );
  }

  Future<void> _markMessageState(
    OutboxEntryRow entry,
    MessageState state,
    String? reason,
  ) async {
    if (entry.command != ConversationCommands.messageSend) return;

    final clientMessageId =
        _decodePayload(entry.payload)['clientMessageId']?.toString() ??
        entry.id;

    await _messages.updateState(
      messageId: clientMessageId,
      state: state,
      failureReason: reason,
    );
  }

  /// Exponential backoff with full jitter, capped at a minute.
  ///
  /// Jittered so a workspace whose agents all lost connection together does
  /// not resend in one synchronised burst the moment it returns.
  Duration _backoff(int attempts) {
    const base = 2000;
    const ceiling = 60000;

    final exponential = base * pow(2, (attempts - 1).clamp(0, 6));
    final capped = min(exponential.toDouble(), ceiling.toDouble());

    return Duration(milliseconds: (_random.nextDouble() * capped).round());
  }

  /// Puts a failed entry back in the queue at the user's request.
  Future<void> retry(String outboxId) async {
    final entry = await _outbox.find(outboxId);

    if (entry == null) {
      throw const NotFoundFailure(message: 'That message is no longer queued.');
    }

    await _outbox.resetForRetry(outboxId, now: _clock().toUtc());
    await _markMessageState(entry, MessageState.pending, null);

    await drain();
  }

  /// Abandons a queued mutation and removes its optimistic row.
  Future<void> discard(String outboxId) async {
    final entry = await _outbox.find(outboxId);

    if (entry == null) return;

    await _database.transaction(() async {
      await _messages.remove(outboxId);
      await _outbox.remove(outboxId);
    });
  }

  /// Counts of unsettled work, for the sync indicator.
  Stream<OutboxSummary> watchSummary({String? scopeId}) {
    return _outbox.watchUnsettled(scopeId: scopeId).map((rows) {
      var pending = 0;
      var failed = 0;

      for (final row in rows) {
        if (row.status == OutboxStatus.failed) {
          failed += 1;
        } else {
          pending += 1;
        }
      }

      return OutboxSummary(pending: pending, failed: failed);
    });
  }

  /// Drops acknowledged rows older than a day.
  Future<int> prune() => _outbox.pruneCompleted(
    before: _clock().toUtc().subtract(const Duration(days: 1)),
  );

  static Map<String, Object?> _decodePayload(String raw) {
    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException('Queued payload was not an object.');
    }

    return Map<String, Object?>.from(decoded);
  }

  void _announce(ConversationAppEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> dispose() => _events.close();
}

/// How much unsettled work the queue holds.
final class OutboxSummary {
  const OutboxSummary({required this.pending, required this.failed});

  final int pending;
  final int failed;

  bool get isEmpty => pending == 0 && failed == 0;
}
