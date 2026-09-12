import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../contracts/customer_directory_capability.dart';
import 'customer_sync_coordinator.dart';

/// This feature's answer to [CustomerDirectoryCapability].
///
/// The same arrangement auth uses for `SessionCapability`: the contract says
/// what another feature needs, a coordinator here implements it, and the
/// composition root joins the two. The caller card does not know this class
/// exists, and this feature does not know who is listening.
class CustomerDirectoryCoordinator implements CustomerDirectoryCapability {
  const CustomerDirectoryCoordinator({
    required CustomerRepository customers,
    required CustomerSyncCoordinator sync,
  }) : _customers = customers,
       _sync = sync;

  final CustomerRepository _customers;
  final CustomerSyncCoordinator _sync;

  @override
  Future<Customer?> findByPhone(String number) =>
      _customers.findByPhone(number);

  @override
  Future<Customer?> findById(String customerId) =>
      _customers.findCustomer(customerId);

  @override
  Future<bool> get isReady => _sync.hasCompletedWalk;
}
