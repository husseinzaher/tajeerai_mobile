/// One of a contact's orders, as the conversation's customer panel lists it.
///
/// The slice of the API's order record a reader needs to recognise an order
/// in a list: which one, what state, how much, when. Money is a decimal
/// string as the server sends it; it is displayed, never computed with.
final class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.reference,
    required this.state,
    required this.currency,
    required this.grandTotal,
    required this.placedAt,
  });

  final String id;
  final String customerId;

  /// The customer-facing reference a merchant quotes, without a `#`.
  final String reference;

  /// The server's `OrderState` string - `pending`, `paid`, `shipped`… Kept as
  /// text: the backend adds states without a schema change here, and an enum
  /// would turn each new one into a crash.
  final String state;
  final String currency;
  final String grandTotal;
  final DateTime placedAt;
}
