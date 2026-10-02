import '../../../../failures/app_failure.dart';
import '../../domain/entities/customer_order.dart';
import '../../domain/repositories/customer_order_repository.dart';
import '../contracts/customer_orders_capability.dart';

/// This feature's answer to [CustomerOrdersCapability].
class CustomerOrdersCoordinator implements CustomerOrdersCapability {
  const CustomerOrdersCoordinator({required CustomerOrderRepository orders})
    : _orders = orders;

  final CustomerOrderRepository _orders;

  @override
  Stream<List<CustomerOrder>> watchForCustomer(String customerId) =>
      _orders.watchForCustomer(customerId);

  @override
  Future<void> refresh(String customerId) async {
    try {
      await _orders.synchronizeForCustomer(customerId);
    } on AppFailure {
      // Offline, throttled, or a server error. The local copy stands.
    }
  }
}
