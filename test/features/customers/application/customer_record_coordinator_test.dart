import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/customers/application/coordinators/customer_record_coordinator.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';

class _Contacts implements CustomerRepository {
  _Contacts({this.refreshed, this.failure});

  final Customer? refreshed;
  final AppFailure? failure;

  int refreshes = 0;
  int noteSyncs = 0;

  @override
  Future<Customer?> refresh(String customerId) async {
    refreshes++;
    if (failure != null) throw failure!;

    return refreshed;
  }

  @override
  Future<int> synchronizeNotes(String customerId) async {
    noteSyncs++;

    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The contract's one promise about refreshing: it never throws at the panel,
/// and it fetches no entries for a contact the server no longer has.
void main() {
  final Customer sara = Customer(
    id: 'c1',
    name: 'Sara',
    createdAt: DateTime.utc(2026),
  );

  test('refreshes the contact, then their entries', () async {
    final _Contacts contacts = _Contacts(refreshed: sara);

    await CustomerRecordCoordinator(customers: contacts).refresh('c1');

    expect(contacts.refreshes, 1);
    expect(contacts.noteSyncs, 1);
  });

  test('fetches no entries for a contact the server has removed', () async {
    final _Contacts contacts = _Contacts();

    await CustomerRecordCoordinator(customers: contacts).refresh('c1');

    expect(contacts.noteSyncs, 0);
  });

  /* Offline is ordinary. The panel keeps drawing what the phone holds. */
  test('swallows a failed fetch', () async {
    final _Contacts contacts = _Contacts(
      failure: const TransportFailure(message: 'offline'),
    );

    await expectLater(
      CustomerRecordCoordinator(customers: contacts).refresh('c1'),
      completes,
    );
  });
}
