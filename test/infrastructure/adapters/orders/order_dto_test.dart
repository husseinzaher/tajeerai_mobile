import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/orders/domain/entities/customer_order.dart';
import 'package:TajeerAi/infrastructure/adapters/orders/models/order_dto.dart';

/// The order record as the API answers it, reduced to what the panel keeps.
void main() {
  test('decodes the slice the panel shows', () {
    final CustomerOrder order = OrderDto.decode(<String, Object?>{
      'id': 'o1',
      'customerId': 'c1',
      'reference': '1042',
      'state': 'delivered',
      'currency': 'SAR',
      'grandTotal': '450.00',
      'placedAt': '2026-09-30T10:00:00.000Z',
      'items': <Object?>[],
    });

    expect(order.id, 'o1');
    expect(order.customerId, 'c1');
    expect(order.reference, '1042');
    expect(order.state, 'delivered');
    expect(order.currency, 'SAR');
    /* Money stays a string: it is displayed, never computed with. */
    expect(order.grandTotal, '450.00');
    expect(order.placedAt, DateTime.utc(2026, 9, 30, 10));
  });

  /* A state this build does not know is kept, not rejected. */
  test('keeps an unknown state as the server named it', () {
    final CustomerOrder order = OrderDto.decode(<String, Object?>{
      'id': 'o1',
      'reference': '1',
      'state': 'on_hold',
      'currency': 'SAR',
      'grandTotal': '1',
      'placedAt': '2026-09-30T10:00:00.000Z',
    }, customerId: 'c1');

    expect(order.state, 'on_hold');
    expect(order.customerId, 'c1');
  });

  test('reads the paginated envelope and skips what is not an order', () {
    final List<CustomerOrder> orders = OrderDto.decodeList(<Object?>[
      <String, Object?>{
        'id': 'o1',
        'reference': '1',
        'placedAt': '2026-01-01T00:00:00Z',
      },
      'garbage',
      null,
    ]);

    expect(orders.map((CustomerOrder o) => o.id), <String>['o1']);
  });

  test('refuses an order without an id', () {
    expect(
      () => OrderDto.decode(<String, Object?>{'reference': '1'}),
      throwsFormatException,
    );
  });
}
