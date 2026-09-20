import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/application/contracts/customer_directory_capability.dart';
import 'package:TajeerAi/features/customers/application/coordinators/customer_directory_coordinator.dart';
import 'package:TajeerAi/features/customers/application/coordinators/customer_sync_coordinator.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

class _Contacts implements CustomerRepository {
  _Contacts({this.byPhone, this.byId});

  final Customer? byPhone;
  final Customer? byId;

  final List<String> phonesAsked = <String>[];

  @override
  Future<Customer?> findByPhone(String number) async {
    phonesAsked.add(number);

    return byPhone;
  }

  @override
  Future<Customer?> findCustomer(String customerId) async => byId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase database;

  setUp(() => database = openTestDatabase());
  tearDown(() => database.close());

  CustomerDirectoryCapability directoryFor(CustomerRepository contacts) {
    return CustomerDirectoryCoordinator(
      customers: contacts,
      sync: CustomerSyncCoordinator(
        customers: contacts,
        syncDao: database.syncDao,
        logger: Logger('test', verbose: false),
        clock: () => testEpoch,
      ),
    );
  }

  final Customer ada = Customer(
    id: 'c1',
    name: 'Ada Lovelace',
    phone: '+966501234567',
    createdAt: testEpoch,
  );

  test('answers a ringing number with the contact behind it', () async {
    final _Contacts contacts = _Contacts(byPhone: ada);

    expect((await directoryFor(contacts).findByPhone('0501234567'))?.id, 'c1');
    expect(contacts.phonesAsked, <String>['0501234567']);
  });

  test('answers nothing for a number the workspace does not know', () async {
    expect(await directoryFor(_Contacts()).findByPhone('0500000000'), isNull);
  });

  test('answers one contact by id, for a screen opened from a card', () async {
    expect((await directoryFor(_Contacts(byId: ada)).findById('c1'))?.id, 'c1');
  });

  /*
    The card asks before it offers "Add as customer". On a device that has not
    finished a walk, "the workspace does not know this number" is not something
    this app has earned the right to say.
  */
  test('is not ready until a walk has finished', () async {
    final CustomerDirectoryCapability directory = directoryFor(_Contacts());

    expect(await directory.isReady, isFalse);

    await database.syncDao.markSynchronized(
      CustomerSyncCoordinator.scope,
      syncedAt: testEpoch,
      now: testEpoch,
    );

    expect(await directory.isReady, isTrue);
  });
}
