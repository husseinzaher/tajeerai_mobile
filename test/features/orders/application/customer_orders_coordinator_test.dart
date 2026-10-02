import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/orders/application/coordinators/customer_orders_coordinator.dart';
import 'package:TajeerAi/features/orders/domain/entities/customer_order.dart';
import 'package:TajeerAi/features/orders/domain/repositories/customer_order_repository.dart';

class _Orders implements CustomerOrderRepository {
  _Orders({this.failure});

  final AppFailure? failure;
  final List<String> synced = <String>[];

  @override
  Stream<List<CustomerOrder>> watchForCustomer(String customerId) =>
      Stream<List<CustomerOrder>>.value(const <CustomerOrder>[]);

  @override
  Future<int> synchronizeForCustomer(String customerId) async {
    synced.add(customerId);
    if (failure != null) throw failure!;

    return 0;
  }
}

void main() {
  test('refreshes the contact’s orders', () async {
    final _Orders orders = _Orders();

    await CustomerOrdersCoordinator(orders: orders).refresh('c1');

    expect(orders.synced, <String>['c1']);
  });

  /* The orders tab must open offline; a failed fetch is not an error state. */
  test('swallows a failed fetch', () async {
    final _Orders orders = _Orders(
      failure: const TransportFailure(message: 'offline'),
    );

    await expectLater(
      CustomerOrdersCoordinator(orders: orders).refresh('c1'),
      completes,
    );
  });
}
