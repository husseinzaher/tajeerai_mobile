import 'package:drift/drift.dart';

import '../../../../failures/app_failure.dart';
import '../../../../features/orders/domain/entities/customer_order.dart';
import '../../../../features/orders/domain/repositories/customer_order_repository.dart';
import '../../../api/http_exception.dart';
import '../../../storage/database/app_database.dart';
import '../local/order_dao.dart';
import '../remote/order_remote_data_source.dart';

/// [CustomerOrderRepository] over the local table and the orders endpoint.
class CustomerOrderRepositoryImpl implements CustomerOrderRepository {
  const CustomerOrderRepositoryImpl({
    required OrderDao dao,
    required OrderRemoteDataSource remote,
  }) : _dao = dao,
       _remote = remote;

  final OrderDao _dao;
  final OrderRemoteDataSource _remote;

  @override
  Stream<List<CustomerOrder>> watchForCustomer(String customerId) {
    return _dao
        .watchForCustomer(customerId)
        .map(
          (List<CustomerOrderRow> rows) =>
              rows.map(_toOrder).toList(growable: false),
        );
  }

  @override
  Future<int> synchronizeForCustomer(String customerId) async {
    final List<CustomerOrder> orders = await _guard(
      () => _remote.fetchRecentForCustomer(customerId),
    );

    await _dao.replaceForCustomer(
      customerId,
      orders.map(_toCompanion).toList(growable: false),
    );

    return orders.length;
  }

  /// Infrastructure exceptions stop here, as `AppFailure`s.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on HttpException catch (error) {
      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The server sent an unexpected response.',
        cause: error,
      );
    }
  }

  CustomerOrder _toOrder(CustomerOrderRow row) {
    return CustomerOrder(
      id: row.id,
      customerId: row.customerId,
      reference: row.reference,
      state: row.state,
      currency: row.currency,
      grandTotal: row.grandTotal,
      placedAt: row.placedAt,
    );
  }

  CustomerOrdersCompanion _toCompanion(CustomerOrder order) {
    return CustomerOrdersCompanion(
      id: Value<String>(order.id),
      customerId: Value<String>(order.customerId),
      reference: Value<String>(order.reference),
      state: Value<String>(order.state),
      currency: Value<String>(order.currency),
      grandTotal: Value<String>(order.grandTotal),
      placedAt: Value<DateTime>(order.placedAt),
    );
  }
}
