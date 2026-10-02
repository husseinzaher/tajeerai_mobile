import '../../domain/entities/customer_order.dart';

// Re-exported so a consumer names the type through this door.
export '../../domain/entities/customer_order.dart' show CustomerOrder;

/// A contact's recent orders, as another feature may read them.
///
/// The conversation screen's customer panel draws an orders tab; this is the
/// door it reaches them through. Read-only, and bounded to what the panel
/// shows - a handful of recent orders, not an order book.
abstract interface class CustomerOrdersCapability {
  /// Newest first. Reads the local database.
  Stream<List<CustomerOrder>> watchForCustomer(String customerId);

  /// Brings the local copy up to date. Fails quietly offline.
  Future<void> refresh(String customerId);
}
