import 'package:drift/drift.dart';

import '../../../storage/database/app_database.dart';
import 'order_tables.dart';

part 'order_dao.g.dart';

/// Reads and replaces a contact's recent orders.
@DriftAccessor(tables: <Type>[CustomerOrders])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.database);

  /// One contact's orders, newest first - what the panel's tab reads.
  Stream<List<CustomerOrderRow>> watchForCustomer(String customerId) {
    return (select(customerOrders)
          ..where(
            ($CustomerOrdersTable row) => row.customerId.equals(customerId),
          )
          ..orderBy(<OrderClauseGenerator<$CustomerOrdersTable>>[
            ($CustomerOrdersTable row) => OrderingTerm.desc(row.placedAt),
          ]))
        .watch();
  }

  /// Replaces one contact's orders with what the server just returned.
  ///
  /// Wholesale, like the notes: nothing is edited locally, so a difference
  /// can only mean the server is right.
  Future<void> replaceForCustomer(
    String customerId,
    List<CustomerOrdersCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(customerOrders)..where(
            ($CustomerOrdersTable row) => row.customerId.equals(customerId),
          ))
          .go();

      await batch((Batch batch) => batch.insertAll(customerOrders, rows));
    });
  }
}
