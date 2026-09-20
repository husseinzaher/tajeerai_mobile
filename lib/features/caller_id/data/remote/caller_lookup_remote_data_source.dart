import '../../../../infrastructure/network/http_client.dart';
import '../../domain/entities/caller_identity.dart';

/// Authenticated caller lookup against the workspace directory.
class CallerLookupRemoteDataSource {
  const CallerLookupRemoteDataSource(this._http);

  final HttpClient _http;

  static const Duration lookupTimeout = Duration(milliseconds: 1200);

  Future<CallerIdentity?> lookup(String normalizedPhone) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/customers/lookup',
      query: <String, Object?>{'phone': normalizedPhone},
    );

    final Map<String, Object?>? data = json['data'] as Map<String, Object?>?;

    if (data == null) return null;

    final String? id = data['id']?.toString();
    final String? name = data['name']?.toString();

    if (id == null || name == null || name.trim().isEmpty) return null;

    return CallerIdentity(
      phoneNumber: normalizedPhone,
      displayName: name.trim(),
      businessName: data['typeName']?.toString(),
      avatarUrl: data['photoUrl']?.toString(),
      tags: _decodeTags(data['tags']),
      source: CallerIdentitySource.server,
      customerId: id,
    );
  }

  static List<String> _decodeTags(Object? raw) {
    if (raw is! List<Object?>) return const <String>[];

    return raw
        .map((Object? value) => value?.toString().trim())
        .whereType<String>()
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
