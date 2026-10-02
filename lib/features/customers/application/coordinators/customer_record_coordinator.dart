import '../../../../failures/app_failure.dart';
import '../../domain/repositories/customer_repository.dart';
import '../contracts/customer_record_capability.dart';

/// This feature's answer to [CustomerRecordCapability].
///
/// The same arrangement as `CustomerDirectoryCoordinator`: the contract says
/// what another feature needs, this implements it over the repository, and the
/// composition root joins the two.
class CustomerRecordCoordinator implements CustomerRecordCapability {
  const CustomerRecordCoordinator({required CustomerRepository customers})
    : _customers = customers;

  final CustomerRepository _customers;

  @override
  Stream<Customer?> watchCustomer(String customerId) =>
      _customers.watchCustomer(customerId);

  @override
  Stream<List<CustomerNote>> watchNotes(String customerId) =>
      _customers.watchNotes(customerId);

  @override
  Future<void> refresh(String customerId) async {
    try {
      // A contact the server no longer has is removed by `refresh`; there are
      // no entries left to fetch for them.
      if (await _customers.refresh(customerId) == null) return;

      await _customers.synchronizeNotes(customerId);
    } on AppFailure {
      // Offline, throttled, or a server error. The local copy stands.
    }
  }
}
