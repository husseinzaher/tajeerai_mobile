import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../customers/application/contracts/customer_record_capability.dart';
import '../../../orders/application/contracts/customer_orders_capability.dart';

part 'customer_panel_controller.g.dart';

/// What the conversation's customer panel reads, and how it refreshes.
///
/// Three streams from the local database - the contact, their entries, their
/// recent orders - reached through the customers and orders features'
/// contracts, never their internals. Each is readable offline and re-emits
/// when a sync writes a row, so the panel draws at once from what the device
/// holds and fills in as the server answers.
///
/// The orders refresh is its own provider, and the orders tab is what watches
/// it: an order list is the one part of this panel that costs a request, and
/// a panel opened to read a phone number should not pay for it.

@riverpod
Stream<Customer?> panelCustomer(Ref ref, String customerId) {
  return ref.watch(customerRecordProvider).watchCustomer(customerId);
}

@riverpod
Stream<List<CustomerNote>> panelNotes(Ref ref, String customerId) {
  return ref.watch(customerRecordProvider).watchNotes(customerId);
}

@riverpod
Stream<List<CustomerOrder>> panelOrders(Ref ref, String customerId) {
  return ref.watch(customerOrdersProvider).watchForCustomer(customerId);
}

/// Brings the contact and their entries up to date. Fires once per contact
/// while the panel is open; the contract swallows a failed fetch so what is
/// stored stays on screen.
@riverpod
Future<void> panelRefresh(Ref ref, String customerId) {
  return ref.watch(customerRecordProvider).refresh(customerId);
}

/// Brings the contact's recent orders up to date. Watched only by the orders
/// tab, so the request is made only when somebody opens it.
@riverpod
Future<void> panelOrdersRefresh(Ref ref, String customerId) {
  return ref.watch(customerOrdersProvider).refresh(customerId);
}
