import 'package:drift/drift.dart';

import '../../../../infrastructure/database/app_database.dart';
import '../../domain/value_objects/phone_digits.dart';
import '../models/customer_tags.dart';
import 'customer_tables.dart';

part 'customer_dao.g.dart';

/// Row access for contacts and their entries.
///
/// Storage only -- no business rules. What it does own is the derivation that
/// makes a phone lookup an index hit: [upsertAll] writes `phoneDigits` and
/// `phoneSuffix` from the stored number on every write, so no caller can
/// insert a row a caller card would then fail to find.
@DriftAccessor(tables: <Type>[Customers, CustomerNotes])
class CustomerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerDaoMixin {
  CustomerDao(super.database);

  /// The contact list, as a reactive query.
  ///
  /// [searchTerm] is matched against the name, the email and the number's
  /// digits -- somebody looking for a person types one of those three, and
  /// typing a number with spaces in it must still find the row.
  Stream<List<CustomerRow>> watchCustomers({
    String? searchTerm,
    String? tag,
    int limit = 100,
  }) {
    final SimpleSelectStatement<$CustomersTable, CustomerRow> query = select(
      customers,
    );

    final String? term = searchTerm?.trim();

    if (term != null && term.isNotEmpty) {
      final String pattern = '%$term%';
      final String digits = PhoneDigits.bare(term);

      query.where(($CustomersTable row) {
        final Expression<bool> byText =
            row.name.like(pattern) | row.email.like(pattern);

        // A term with no digits in it would otherwise match every row whose
        // number is not null, because '%%' matches anything.
        return digits.isEmpty
            ? byText
            : byText | row.phoneDigits.like('%$digits%');
      });
    }

    if (tag != null && tag.isNotEmpty) {
      // The column is a JSON array of strings; the quotes are what stop `vip`
      // from also matching `vip-2024`.
      query.where(($CustomersTable row) => row.tags.like('%"$tag"%'));
    }

    query
      ..orderBy(<OrderClauseGenerator<$CustomersTable>>[
        ($CustomersTable row) => OrderingTerm.desc(row.updatedAt),
        ($CustomersTable row) => OrderingTerm.desc(row.createdAt),
      ])
      ..limit(limit);

    return query.watch();
  }

  Stream<CustomerRow?> watchCustomer(String customerId) {
    return (select(customers)
          ..where(($CustomersTable row) => row.id.equals(customerId)))
        .watchSingleOrNull();
  }

  Future<CustomerRow?> findById(String customerId) {
    return (select(customers)
          ..where(($CustomersTable row) => row.id.equals(customerId)))
        .getSingleOrNull();
  }

  /// The contact behind a ringing number.
  ///
  /// Compares the stored suffix to the caller's, which is an equality test an
  /// index can serve -- `LIKE '%...'` cannot. When two contacts share a
  /// suffix the most recently updated wins, because that is the row a member
  /// has most recently had a reason to touch.
  Future<CustomerRow?> findByPhone(String number) {
    final String suffix = PhoneDigits.suffix(number);

    if (suffix.isEmpty) return Future<CustomerRow?>.value();

    return (select(customers)
          ..where(($CustomersTable row) => row.phoneSuffix.equals(suffix))
          ..orderBy(<OrderClauseGenerator<$CustomersTable>>[
            ($CustomersTable row) => OrderingTerm.desc(row.updatedAt),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Every tag in use locally, flattened from the JSON arrays.
  ///
  /// Read whole and split in Dart rather than in SQL: SQLite's `json_each`
  /// would need a custom query for a list that is a few dozen strings long on
  /// the largest workspace this screen serves.
  Stream<List<String>> watchTags() {
    return (select(customers)
          ..where(($CustomersTable row) => row.tags.isNotValue('[]')))
        .watch()
        .map((List<CustomerRow> rows) {
          final Set<String> seen = <String>{};

          for (final CustomerRow row in rows) {
            for (final String tag in CustomerTags.decode(row.tags)) {
              seen.add(tag);
            }
          }

          final List<String> sorted = seen.toList()..sort();

          return sorted;
        });
  }

  /// Writes a page of contacts, stamping each with the walk that saw it.
  ///
  /// One transaction per page, so an interrupted walk leaves whole pages
  /// behind rather than half of one -- which is what makes resuming from a
  /// stored page number safe.
  Future<void> upsertAll(
    List<CustomersCompanion> rows, {
    required DateTime seenAt,
  }) {
    return batch((Batch batch) {
      for (final CustomersCompanion row in rows) {
        batch.insert(
          customers,
          row.copyWith(seenAt: Value<DateTime>(seenAt)),
          onConflict: DoUpdate(
            (_) => row.copyWith(seenAt: Value<DateTime>(seenAt)),
          ),
        );
      }
    });
  }

  /// Deletes rows a completed walk did not see.
  ///
  /// Only after a walk that finished: a pass that stopped halfway has not
  /// looked everywhere, and deleting on its evidence would empty the list of
  /// everybody on the pages it never asked for.
  Future<int> deleteUnseenSince(DateTime walkStartedAt) {
    return (delete(customers)..where(
          ($CustomersTable row) => row.seenAt.isSmallerThanValue(walkStartedAt),
        ))
        .go();
  }

  Future<int> deleteById(String customerId) {
    return (delete(
      customers,
    )..where(($CustomersTable row) => row.id.equals(customerId))).go();
  }

  Future<int> count() async {
    final Expression<int> total = customers.id.count();
    final TypedResult row = await (selectOnly(
      customers,
    )..addColumns(<Expression<Object>>[total])).getSingle();

    return row.read(total) ?? 0;
  }

  /* ----------------------------------------------------------- entries */

  Stream<List<CustomerNoteRow>> watchNotes(String customerId) {
    return (select(customerNotes)
          ..where(
            ($CustomerNotesTable row) => row.customerId.equals(customerId),
          )
          ..orderBy(<OrderClauseGenerator<$CustomerNotesTable>>[
            ($CustomerNotesTable row) => OrderingTerm.desc(row.createdAt),
          ]))
        .watch();
  }

  /// Replaces one contact's entries with what the server just returned.
  ///
  /// Wholesale rather than merged: the list is append-only on the server and
  /// never edited here, so there is no local state to preserve and a
  /// difference can only mean the server is right.
  Future<void> replaceNotes(
    String customerId,
    List<CustomerNotesCompanion> rows,
  ) {
    return transaction(() async {
      await (delete(customerNotes)..where(
            ($CustomerNotesTable row) => row.customerId.equals(customerId),
          ))
          .go();

      await batch((Batch batch) => batch.insertAll(customerNotes, rows));
    });
  }

  Future<void> insertNote(CustomerNotesCompanion row) {
    return into(customerNotes).insert(row, mode: InsertMode.insertOrReplace);
  }
}
