import 'package:drift/drift.dart';

/// A contact's recent orders, as the conversation's customer panel shows them.
///
/// Columns mirror the slice of the API's order record the panel draws - the
/// reference, the state, the money and when it was placed - and nothing else:
/// no lines, no addresses, no payment detail. A screen that needs those is the
/// order screen, which does not exist here yet, and a table that anticipates
/// it is a table nobody has had to get right.
///
/// Replaced wholesale per contact on each refresh, like `customer_notes`: the
/// server's list is the truth and nothing is written locally.
@DataClassName('CustomerOrderRow')
class CustomerOrders extends Table {
  /// The server's uuid.
  TextColumn get id => text()();

  TextColumn get customerId => text()();

  /// The customer-facing reference a merchant quotes: `1042`.
  TextColumn get reference => text()();

  /// The server's `OrderState` string, kept as text on purpose - the backend
  /// adds states without a schema change here.
  TextColumn get state => text()();

  TextColumn get currency => text()();

  /// A decimal string, as the API sends money. Never parsed to a double: a
  /// total is displayed, not computed with.
  TextColumn get grandTotal => text()();

  DateTimeColumn get placedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
