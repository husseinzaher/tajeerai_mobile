import 'dart:async';
import 'dart:convert';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/daos/sync_dao.dart';
import '../../../../infrastructure/logging/logger.dart';
import '../../domain/repositories/customer_repository.dart';

/// Walks the server's contact list into local storage.
///
/// **A paced, resumable full walk**, which is what the shape of the endpoint
/// forces. Customers are numbered pages over HTTP with no server cursor, so
/// there is no "everything since" to ask for -- the only way to be sure a
/// device has every contact is to read all of them, and the only way to learn
/// that one was deleted is to notice it missing from a walk that finished.
///
/// Three properties earn their complexity:
///
/// - **Ordered by `updatedAt` ascending.** Rows edited during the walk move to
///   the end, behind the page being read, instead of shifting rows backwards
///   past it. A descending walk puts a freshly-edited contact on page one and
///   silently drops whoever fell off its bottom.
/// - **Resumable.** The page just written is stored in `SyncStates.pageCursor`
///   with the time the walk began, so a process killed at page seven resumes
///   at page eight rather than starting again -- and a resumed walk keeps the
///   original start time, or the reconciliation at the end would delete every
///   row the earlier pages stamped.
/// - **Paced.** A pause between pages, so a device catching up on a workspace
///   with tens of thousands of contacts does not spend the user's battery and
///   the server's budget as fast as it can.
///
/// Deletions are reconciled only after a walk that *completed*. A pass that
/// stopped halfway has not looked everywhere, and deleting on its evidence
/// would empty the list of everyone on the pages it never asked for.
class CustomerSyncCoordinator {
  CustomerSyncCoordinator({
    required CustomerRepository customers,
    required SyncDao syncDao,
    required Logger logger,
    DateTime Function() clock = DateTime.now,
    Future<void> Function(Duration) sleep = _defaultSleep,
  }) : _customers = customers,
       _syncDao = syncDao,
       _logger = logger,
       _clock = clock,
       _sleep = sleep;

  final CustomerRepository _customers;
  final SyncDao _syncDao;
  final Logger _logger;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;

  /// The synchronisation scope for the contact list.
  static const String scope = 'customers';

  /// How many contacts one request asks for. The API's own ceiling.
  static const int pageSize = 100;

  /// The pause between pages. Long enough that a long walk is background work
  /// rather than a burst, short enough that a first sync finishes while
  /// somebody is still looking at the app.
  static const Duration pacing = Duration(milliseconds: 250);

  /// A walk this old is abandoned rather than resumed.
  ///
  /// A resumed walk carries its original start time into the reconciliation at
  /// the end, so resuming a walk from last week would delete every contact
  /// whose row has not been touched since -- which is most of them. Past this,
  /// starting over is both cheaper and correct.
  static const Duration resumeWindow = Duration(hours: 6);

  static Future<void> _defaultSleep(Duration duration) =>
      Future<void>.delayed(duration);

  bool _running = false;

  /// Whether the device has a complete contact list.
  ///
  /// What the caller card asks before it offers "Add as customer": on a device
  /// that has never finished a walk, "the workspace does not know this number"
  /// is not something this app has earned the right to say.
  Future<bool> get hasCompletedWalk async =>
      await _syncDao.cursorFor(scope) != null;

  /// Runs the walk, resuming an interrupted one where it stopped.
  ///
  /// Returns how many contacts were written. Concurrent calls are ignored
  /// rather than queued -- two walks would fight over the same cursor, and the
  /// second would reconcile against the first's start time.
  Future<int> synchronize() async {
    if (_running) return 0;

    _running = true;

    final DateTime now = _clock().toUtc();

    try {
      await _syncDao.markSyncing(scope, now: now);

      final _WalkPosition position = await _resume(now);
      int written = 0;
      int page = position.nextPage;

      while (true) {
        final CustomerPage fetched = await _customers.synchronizePage(
          page: page,
          perPage: pageSize,
        );

        written += fetched.customers.length;

        if (!fetched.hasMore) break;

        // Stored after the page it follows has landed, so a kill between the
        // two resumes on the page that did not.
        await _syncDao.savePageCursor(
          scope,
          position.startedAt.resumeToken(page + 1),
        );

        await _sleep(pacing);
        page += 1;
      }

      final int removed = await _customers.reconcileDeletions(
        seenIds: const <String>{},
        walkStartedAt: position.startedAt,
      );

      await _syncDao.savePageCursor(scope, null);
      await _syncDao.markSynchronized(
        scope,
        // The device's own clock, and the one place in this app that is
        // acceptable: this cursor is not a window into the server's history
        // the way `conversation:sync`'s is, only a record that a walk finished.
        // Nothing is re-requested from it.
        syncedAt: _clock().toUtc(),
        now: _clock().toUtc(),
      );

      _logger.info(
        'Customer sync finished: $written written, $removed removed.',
      );

      return written;
    } on AppFailure catch (failure) {
      // The cursor is left where it is, so the next attempt resumes rather
      // than re-reading the pages that landed.
      await _syncDao.markFailed(
        scope,
        error: failure.message,
        now: _clock().toUtc(),
      );

      _logger.warning('Customer sync failed: ${failure.message}');

      return 0;
    } finally {
      _running = false;
    }
  }

  /// Removes a contact the server no longer has.
  ///
  /// Called when a detail screen's refresh 404s: a deletion reaches a device
  /// either that way or through the next full walk, and waiting for the walk
  /// leaves somebody looking at a contact that is gone.
  Future<void> forget(String customerId) => _customers.forget(customerId);

  /// Where this walk starts, and what start time it reconciles against.
  Future<_WalkPosition> _resume(DateTime now) async {
    final String? token = await _syncDao.pageCursorFor(scope);
    final _WalkPosition? stored = _WalkPosition.parse(token);

    if (stored == null || now.difference(stored.startedAt) > resumeWindow) {
      return _WalkPosition(startedAt: now, nextPage: 1);
    }

    return stored;
  }
}

/// A resume token: which page comes next, and when the walk it belongs to
/// began.
///
/// Both halves are needed. The page alone would resume correctly and then
/// reconcile against the wrong moment, deleting every row the abandoned walk's
/// earlier pages had already stamped.
final class _WalkPosition {
  const _WalkPosition({required this.startedAt, required this.nextPage});

  final DateTime startedAt;
  final int nextPage;

  static _WalkPosition? parse(String? token) {
    if (token == null || token.isEmpty) return null;

    try {
      final Object? decoded = jsonDecode(token);

      if (decoded is! Map<String, Object?>) return null;

      final DateTime? startedAt = DateTime.tryParse(
        decoded['startedAt']?.toString() ?? '',
      );
      final int? page = decoded['nextPage'] is int
          ? decoded['nextPage']! as int
          : int.tryParse(decoded['nextPage']?.toString() ?? '');

      if (startedAt == null || page == null || page < 1) return null;

      return _WalkPosition(startedAt: startedAt.toUtc(), nextPage: page);
    } on FormatException {
      return null;
    }
  }
}

extension on DateTime {
  String resumeToken(int nextPage) => jsonEncode(<String, Object?>{
    'startedAt': toIso8601String(),
    'nextPage': nextPage,
  });
}
