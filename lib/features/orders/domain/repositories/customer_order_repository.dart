import '../entities/customer_order.dart';

/// A contact's recent orders: read locally, refreshed from the server.
///
/// Local-first like every repository here: [watchForCustomer] reads the
/// database and re-emits when a sync writes rows; [synchronizeForCustomer] is
/// the only method that reaches the network.
abstract interface class CustomerOrderRepository {
  /// Newest first.
  Stream<List<CustomerOrder>> watchForCustomer(String customerId);

  /// Fetches the contact's most recent orders and replaces the local copy.
  /// Returns how many were written.
  Future<int> synchronizeForCustomer(String customerId);
}
