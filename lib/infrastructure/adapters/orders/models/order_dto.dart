import '../../../../features/orders/domain/entities/customer_order.dart';

/// Decodes the API's order record into the slice the panel keeps.
///
/// Forgiving by design, like the customer decoder: an unknown state stays a
/// string, an unreadable timestamp falls back rather than throws. The money
/// fields arrive as decimal strings and stay strings.
abstract final class OrderDto {
  static CustomerOrder decode(Map<String, Object?> json, {String? customerId}) {
    final String? id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Order carried no id.');
    }

    return CustomerOrder(
      id: id,
      customerId: _text(json['customerId']) ?? customerId ?? '',
      reference: _text(json['reference']) ?? '',
      state: _text(json['state']) ?? 'pending',
      currency: _text(json['currency']) ?? '',
      grandTotal: _text(json['grandTotal']) ?? '0',
      placedAt:
          _time(json['placedAt']) ??
          _time(json['createdAt']) ??
          DateTime.now().toUtc(),
    );
  }

  /// The `{data, meta}` envelope every paginated list endpoint answers with.
  static List<CustomerOrder> decodeList(Object? raw, {String? customerId}) {
    final List<Object?> items = raw is List<Object?> ? raw : const <Object?>[];

    return <CustomerOrder>[
      for (final Object? item in items)
        if (_map(item) case final Map<String, Object?> json)
          decode(json, customerId: customerId),
    ];
  }

  static DateTime? _time(Object? raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is! String || raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toUtc();
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map<Object?, Object?>) {
      return raw.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    }

    return null;
  }

  static String? _text(Object? raw) {
    final String? value = raw?.toString().trim();

    return value == null || value.isEmpty ? null : value;
  }
}
