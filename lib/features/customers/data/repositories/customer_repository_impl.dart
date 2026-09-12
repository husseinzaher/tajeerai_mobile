import 'package:drift/drift.dart';

import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/database/app_database.dart';
import '../../../../infrastructure/network/http_exception.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/value_objects/phone_digits.dart';
import '../local/customer_dao.dart';
import '../models/customer_tags.dart';
import '../remote/customer_remote_data_source.dart';

/// Contacts, local-first.
///
/// The translation boundary: rows and payloads become entities here, and
/// `HttpException` becomes an `AppFailure` here. Nothing above this file sees
/// either.
class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl({
    required CustomerDao dao,
    required CustomerRemoteDataSource remote,
    required DateTime Function() clock,
  }) : _dao = dao,
       _remote = remote,
       _clock = clock;

  final CustomerDao _dao;
  final CustomerRemoteDataSource _remote;
  final DateTime Function() _clock;

  @override
  Stream<List<Customer>> watchCustomers({
    String? searchTerm,
    String? tag,
    int limit = 100,
  }) {
    return _dao
        .watchCustomers(searchTerm: searchTerm, tag: tag, limit: limit)
        .map(
          (List<CustomerRow> rows) =>
              rows.map(_toCustomer).toList(growable: false),
        );
  }

  @override
  Stream<Customer?> watchCustomer(String customerId) {
    return _dao
        .watchCustomer(customerId)
        .map((CustomerRow? row) => row == null ? null : _toCustomer(row));
  }

  @override
  Future<Customer?> findCustomer(String customerId) async {
    final CustomerRow? row = await _dao.findById(customerId);

    return row == null ? null : _toCustomer(row);
  }

  @override
  Stream<List<String>> watchTags() => _dao.watchTags();

  @override
  Future<Customer?> findByPhone(String number) async {
    final CustomerRow? row = await _dao.findByPhone(number);

    return row == null ? null : _toCustomer(row);
  }

  @override
  Future<CustomerPage> synchronizePage({
    required int page,
    int perPage = 100,
  }) async {
    final CustomerPage fetched = await _guard(
      () => _remote.fetchPage(page: page, perPage: perPage),
    );

    await _dao.upsertAll(
      fetched.customers.map(_toCompanion).toList(growable: false),
      seenAt: _clock().toUtc(),
    );

    return fetched;
  }

  @override
  Future<int> reconcileDeletions({
    required Set<String> seenIds,
    required DateTime walkStartedAt,
  }) {
    // `seenIds` is not consulted here on purpose. The walk stamps `seenAt` on
    // every row it writes, so "not seen by this walk" is already recorded per
    // row -- and carrying tens of thousands of ids in memory to repeat the
    // same statement with a giant `NOT IN` would be slower and no more
    // correct. The parameter stays on the contract because a future scope
    // that cannot stamp rows would need it.
    return _dao.deleteUnseenSince(walkStartedAt);
  }

  @override
  Future<void> forget(String customerId) => _dao.deleteById(customerId);

  @override
  Future<Customer?> refresh(String customerId) async {
    try {
      final Customer fetched = await _guard(() => _remote.fetchOne(customerId));

      await _dao.upsertAll(<CustomersCompanion>[
        _toCompanion(fetched),
      ], seenAt: _clock().toUtc());

      return fetched;
    } on NotFoundFailure {
      await _dao.deleteById(customerId);

      return null;
    }
  }

  @override
  Future<List<Customer>> searchOnline(String term, {int limit = 25}) {
    return _guard(() => _remote.search(term, limit: limit));
  }

  @override
  Future<Customer> create({
    required String name,
    String? email,
    String? phone,
    List<String> tags = const <String>[],
    String? notes,
    String? typeId,
  }) async {
    final Customer created = await _guard(
      () => _remote.create(<String, Object?>{
        'name': name,
        'email': email,
        // Sent as typed. The server normalises to E.164 with the phone
        // metadata this app deliberately does not carry -- see `PhoneDigits`.
        'phone': phone,
        'tags': tags,
        'notes': notes,
        'typeId': typeId,
      }),
    );

    await _dao.upsertAll(<CustomersCompanion>[
      _toCompanion(created),
    ], seenAt: _clock().toUtc());

    return created;
  }

  @override
  Stream<List<CustomerNote>> watchNotes(String customerId) {
    return _dao
        .watchNotes(customerId)
        .map(
          (List<CustomerNoteRow> rows) =>
              rows.map(_toNote).toList(growable: false),
        );
  }

  @override
  Future<int> synchronizeNotes(String customerId) async {
    final List<CustomerNote> notes = await _guard(
      () => _remote.fetchNotes(customerId),
    );

    await _dao.replaceNotes(
      customerId,
      notes.map(_toNoteCompanion).toList(growable: false),
    );

    return notes.length;
  }

  @override
  Future<CustomerNote> addNote(String customerId, String body) async {
    final CustomerNote note = await _guard(
      () => _remote.addNote(customerId, body),
    );

    // Written locally at once rather than waiting for the next refresh: the
    // screen that returns to the list has to show what was just added, offline
    // or not.
    await _dao.insertNote(_toNoteCompanion(note));

    return note;
  }

  /// Turns a transport failure into the app's own vocabulary.
  ///
  /// A 404 on a contact means the row is gone rather than the request was
  /// wrong, and the coordinator that catches `NotFoundFailure` is what removes
  /// it locally -- so it is translated, not swallowed.
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

  Customer _toCustomer(CustomerRow row) {
    return Customer(
      id: row.id,
      name: row.name,
      email: row.email,
      phone: row.phone,
      locale: row.locale,
      tags: CustomerTags.decode(row.tags),
      notes: row.notes,
      typeId: row.typeId,
      typeName: row.typeName,
      source: row.source,
      photoUrl: row.photoUrl,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// The one place the lookup keys are derived, so no write can produce a row
  /// a caller card would fail to find.
  CustomersCompanion _toCompanion(Customer customer) {
    final String? phone = customer.phone;

    return CustomersCompanion(
      id: Value<String>(customer.id),
      name: Value<String>(customer.name),
      email: Value<String?>(customer.email),
      phone: Value<String?>(phone),
      phoneDigits: Value<String?>(
        phone == null ? null : PhoneDigits.bare(phone),
      ),
      phoneSuffix: Value<String?>(
        phone == null ? null : PhoneDigits.suffix(phone),
      ),
      locale: Value<String>(customer.locale),
      tags: Value<String>(CustomerTags.encode(customer.tags)),
      notes: Value<String?>(customer.notes),
      typeId: Value<String?>(customer.typeId),
      typeName: Value<String?>(customer.typeName),
      source: Value<String?>(customer.source),
      photoUrl: Value<String?>(customer.photoUrl),
      createdAt: Value<DateTime>(customer.createdAt),
      updatedAt: Value<DateTime?>(customer.updatedAt),
    );
  }

  CustomerNote _toNote(CustomerNoteRow row) {
    return CustomerNote(
      id: row.id,
      customerId: row.customerId,
      body: row.body,
      authorId: row.authorId,
      authorName: row.authorName,
      createdAt: row.createdAt,
    );
  }

  CustomerNotesCompanion _toNoteCompanion(CustomerNote note) {
    return CustomerNotesCompanion(
      id: Value<String>(note.id),
      customerId: Value<String>(note.customerId),
      body: Value<String>(note.body),
      authorId: Value<String?>(note.authorId),
      authorName: Value<String?>(note.authorName),
      createdAt: Value<DateTime>(note.createdAt),
    );
  }
}
