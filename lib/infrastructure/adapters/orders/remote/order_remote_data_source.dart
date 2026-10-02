import '../../../../features/orders/domain/entities/customer_order.dart';
import '../../../api/http_client.dart';
import '../models/order_dto.dart';

/// A contact's recent orders, over HTTP.
///
/// HTTP because the socket exposes no order commands - ARCHITECTURE.md §11
/// names orders among the workspace data read this way. One page, newest
/// first, the same ten the web's contact panel shows: this is a glance at a
/// person's history during a conversation, not the order list.
class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._http);

  final HttpClient _http;

  static const int recentLimit = 10;

  Future<List<CustomerOrder>> fetchRecentForCustomer(String customerId) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/orders',
      query: <String, Object?>{
        'customerId': customerId,
        'perPage': recentLimit,
        'sort': 'placedAt',
        'direction': 'desc',
      },
    );

    return OrderDto.decodeList(json['data'], customerId: customerId);
  }
}
