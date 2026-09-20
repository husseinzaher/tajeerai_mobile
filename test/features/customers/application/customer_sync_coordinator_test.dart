import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/customers/application/coordinators/customer_sync_coordinator.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

/// A repository that records the walk rather than performing one.
class _RecordingCustomers implements CustomerRepository {
  _RecordingCustomers({this.lastPage = 1, this.failOnPage});

  final int lastPage;

  /// The page that raises, for the interrupted-walk cases.
  final int? failOnPage;

  final List<int> pagesRead = <int>[];
  final List<DateTime> reconciledAgainst = <DateTime>[];

  @override
  Future<CustomerPage> synchronizePage({
    required int page,
    int perPage = 100,
  }) async {
    pagesRead.add(page);

    if (page == failOnPage) {
      throw const TransportFailure(message: 'offline', isOffline: true);
    }

    return CustomerPage(
      customers: const <Customer>[],
      page: page,
      lastPage: lastPage,
    );
  }

  @override
  Future<int> reconcileDeletions({
    required Set<String> seenIds,
    required DateTime walkStartedAt,
  }) async {
    reconciledAgainst.add(walkStartedAt);

    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;
  late FixedClock clock;
  late List<Duration> paused;

  setUp(() {
    database = openTestDatabase();
    clock = FixedClock(testEpoch);
    paused = <Duration>[];
  });

  tearDown(() => database.close());

  CustomerSyncCoordinator coordinatorFor(CustomerRepository customers) {
    return CustomerSyncCoordinator(
      customers: customers,
      syncDao: database.syncDao,
      logger: Logger('test', verbose: false),
      clock: clock.call,
      sleep: (Duration duration) async => paused.add(duration),
    );
  }

  test('walks every page the server says there is', () async {
    final _RecordingCustomers customers = _RecordingCustomers(lastPage: 3);

    await coordinatorFor(customers).synchronize();

    expect(customers.pagesRead, <int>[1, 2, 3]);
  });

  /*
    Between pages, not before the first and not after the last: a device
    catching up on a large workspace is doing background work, not a burst.
  */
  test('pauses between pages, once fewer than it reads', () async {
    await coordinatorFor(_RecordingCustomers(lastPage: 3)).synchronize();

    expect(paused, hasLength(2));
    expect(paused.first, CustomerSyncCoordinator.pacing);
  });

  test('reconciles deletions only after a walk that finished', () async {
    final _RecordingCustomers completed = _RecordingCustomers(lastPage: 2);
    await coordinatorFor(completed).synchronize();
    expect(completed.reconciledAgainst, hasLength(1));

    final _RecordingCustomers interrupted = _RecordingCustomers(
      lastPage: 3,
      failOnPage: 2,
    );
    await coordinatorFor(interrupted).synchronize();
    expect(
      interrupted.reconciledAgainst,
      isEmpty,
      reason: 'a pass that stopped halfway has not looked everywhere',
    );
  });

  test('resumes an interrupted walk on the page that did not land', () async {
    final _RecordingCustomers interrupted = _RecordingCustomers(
      lastPage: 5,
      failOnPage: 3,
    );
    await coordinatorFor(interrupted).synchronize();
    expect(interrupted.pagesRead, <int>[1, 2, 3]);

    final _RecordingCustomers resumed = _RecordingCustomers(lastPage: 5);
    await coordinatorFor(resumed).synchronize();

    expect(resumed.pagesRead, <int>[3, 4, 5]);
  });

  /*
    A resumed walk carries its original start time into the reconciliation, so
    the earlier pages' stamps still count. Resuming one from last week would
    therefore delete every contact nobody has touched since.
  */
  test('starts over rather than resuming a walk that has gone stale', () async {
    await coordinatorFor(_RecordingCustomers(lastPage: 5, failOnPage: 3))
        .synchronize();

    clock.advance(CustomerSyncCoordinator.resumeWindow * 2);

    final _RecordingCustomers resumed = _RecordingCustomers(lastPage: 5);
    await coordinatorFor(resumed).synchronize();

    expect(resumed.pagesRead.first, 1);
  });

  test('reconciles against when the walk began, not when it ended', () async {
    final _RecordingCustomers customers = _RecordingCustomers(lastPage: 2);
    final CustomerSyncCoordinator coordinator = coordinatorFor(customers);

    await coordinator.synchronize();

    expect(customers.reconciledAgainst.single, testEpoch);
  });

  test('has not completed a walk until one finishes', () async {
    final CustomerSyncCoordinator interrupted = coordinatorFor(
      _RecordingCustomers(lastPage: 3, failOnPage: 2),
    );

    await interrupted.synchronize();
    expect(await interrupted.hasCompletedWalk, isFalse);

    final CustomerSyncCoordinator completed = coordinatorFor(
      _RecordingCustomers(lastPage: 1),
    );

    await completed.synchronize();
    expect(await completed.hasCompletedWalk, isTrue);
  });

  test('ignores a second walk while one is running', () async {
    final _RecordingCustomers customers = _RecordingCustomers(lastPage: 2);
    final CustomerSyncCoordinator coordinator = coordinatorFor(customers);

    await Future.wait(<Future<int>>[
      coordinator.synchronize(),
      coordinator.synchronize(),
    ]);

    expect(customers.pagesRead, <int>[1, 2]);
  });
}
