import '../../../../infrastructure/network/http_client.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_dto.dart';

/// The contact endpoints.
///
/// HTTP rather than the socket because the backend exposes no socket commands
/// for the customer module -- the decision is recorded in `ARCHITECTURE.md`
/// §11, and RULE 36 is what keeps every such call in a file like this one,
/// where the decision can be reviewed.
///
/// Raises `HttpException`; the repository translates it. Nothing above the
/// data layer sees a transport type.
class CustomerRemoteDataSource {
  const CustomerRemoteDataSource(this._http);

  final HttpClient _http;

  /// One page of the contact list, oldest change last.
  ///
  /// Ordered by `updatedAt` ascending so a walk that resumes mid-list does not
  /// re-read pages it has already written: rows that change during the walk
  /// move to the end, behind the page the cursor is on, rather than shifting
  /// rows backwards past it. A descending walk would push a freshly-edited
  /// contact onto page one and silently skip whoever fell off its bottom.
  Future<CustomerPage> fetchPage({required int page, int perPage = 100}) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/customers',
      query: <String, Object?>{
        'page': page,
        'perPage': perPage,
        'sort': 'updatedAt',
        'direction': 'asc',
      },
    );

    return CustomerPage(
      customers: CustomerDto.decodeList(json['data']),
      page: page,
      lastPage: _lastPage(json['meta']) ?? page,
    );
  }

  /// The server's own search, for contacts this device has not synced.
  Future<List<Customer>> search(String term, {int limit = 25}) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/customers',
      query: <String, Object?>{'search': term, 'page': 1, 'perPage': limit},
    );

    return CustomerDto.decodeList(json['data']);
  }

  Future<Customer> fetchOne(String customerId) async {
    return CustomerDto.decode(await _http.get('/v1/customers/$customerId'));
  }

  Future<Customer> create(Map<String, Object?> body) async {
    return CustomerDto.decode(await _http.post('/v1/customers', body: body));
  }

  /// A contact's entries, newest first.
  ///
  /// The endpoint answers with a bare array; `HttpClient` wraps a non-object
  /// body as `{'data': …}`, which is where this reads it from.
  Future<List<CustomerNote>> fetchNotes(String customerId) async {
    final Map<String, Object?> json = await _http.get(
      '/v1/customers/$customerId/notes',
    );

    return CustomerNoteDto.decodeList(json['data'], customerId: customerId);
  }

  Future<CustomerNote> addNote(String customerId, String body) async {
    final Map<String, Object?> json = await _http.post(
      '/v1/customers/$customerId/notes',
      body: <String, Object?>{'body': body},
    );

    return CustomerNoteDto.decode(json, customerId: customerId);
  }

  /// How many pages the walk has left, from the envelope every paginated
  /// endpoint carries. Null when the server did not say, which the caller
  /// reads as "this page was the last one" rather than walking forever.
  static int? _lastPage(Object? meta) {
    if (meta is! Map<Object?, Object?>) return null;

    final Object? raw = meta['lastPage'] ?? meta['totalPages'];

    if (raw is int) return raw;

    return int.tryParse(raw?.toString() ?? '');
  }
}
