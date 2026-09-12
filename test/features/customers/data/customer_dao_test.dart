import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/customers/data/local/customer_dao.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

CustomersCompanion _customer({
  String id = 'c1',
  String name = 'Ada Lovelace',
  String? phone = '+966501234567',
  String? phoneDigits = '966501234567',
  String? phoneSuffix = '501234567',
  String? email,
  String tags = '[]',
  DateTime? updatedAt,
  DateTime? seenAt,
}) {
  return CustomersCompanion.insert(
    id: id,
    name: name,
    phone: Value<String?>(phone),
    phoneDigits: Value<String?>(phoneDigits),
    phoneSuffix: Value<String?>(phoneSuffix),
    email: Value<String?>(email),
    tags: Value<String>(tags),
    createdAt: testEpoch,
    updatedAt: Value<DateTime?>(updatedAt ?? testEpoch),
    seenAt: seenAt ?? testEpoch,
  );
}

void main() {
  late AppDatabase database;
  late CustomerDao dao;

  setUp(() {
    database = openTestDatabase();
    dao = database.customerDao;
  });

  tearDown(() => database.close());

  group('watchCustomers', () {
    test('re-emits when a write lands, which is the whole read path', () async {
      final Stream<List<CustomerRow>> rows = dao.watchCustomers();

      expect(await rows.first, isEmpty);

      // Subscribed before the write, so the emission being waited for is the
      // one the write causes rather than the query that was already running.
      final Future<List<CustomerRow>> written = rows.firstWhere(
        (List<CustomerRow> list) => list.isNotEmpty,
      );

      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: testEpoch);

      expect((await written).single.name, 'Ada Lovelace');
    });

    test('finds a contact by name, by email and by the number typed', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(email: 'ada@demo.test'),
      ], seenAt: testEpoch);

      await expectLater(
        dao.watchCustomers(searchTerm: 'lovelace').first,
        completion(hasLength(1)),
      );
      await expectLater(
        dao.watchCustomers(searchTerm: 'ada@demo').first,
        completion(hasLength(1)),
      );
      // Typed with spaces, stored without: the digits are what match.
      await expectLater(
        dao.watchCustomers(searchTerm: '966 50 123').first,
        completion(hasLength(1)),
      );
    });

    /*
      A term with no digits in it must not fall through to the phone clause,
      where `LIKE '%%'` matches every row that has a number at all.
    */
    test('does not match everyone on a term with no digits', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(),
        _customer(id: 'c2', name: 'Grace'),
      ], seenAt: testEpoch);

      await expectLater(
        dao.watchCustomers(searchTerm: 'zzz').first,
        completion(isEmpty),
      );
    });

    test('narrows to one tag, and not to a tag that starts the same', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(tags: '["vip"]'),
        _customer(id: 'c2', name: 'Grace', tags: '["vip-2024"]'),
      ], seenAt: testEpoch);

      final List<CustomerRow> rows = await dao.watchCustomers(tag: 'vip').first;

      expect(rows.map((CustomerRow row) => row.id), <String>['c1']);
    });
  });

  group('findByPhone', () {
    test('answers for any spelling of the same number', () async {
      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: testEpoch);

      expect((await dao.findByPhone('0501234567'))?.id, 'c1');
      expect((await dao.findByPhone('00966501234567'))?.id, 'c1');
      expect((await dao.findByPhone('+966 50 123 4567'))?.id, 'c1');
    });

    test('answers nothing for a number nobody has', () async {
      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: testEpoch);

      expect(await dao.findByPhone('+966500000000'), isNull);
    });

    /* A withheld number must not pick whichever row has no suffix stored. */
    test('answers nothing when the caller has no number', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(phone: null, phoneSuffix: null),
      ], seenAt: testEpoch);

      expect(await dao.findByPhone(''), isNull);
    });

    test('prefers the contact somebody touched most recently', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(updatedAt: testEpoch),
        _customer(
          id: 'c2',
          name: 'Grace',
          updatedAt: testEpoch.add(const Duration(days: 1)),
        ),
      ], seenAt: testEpoch);

      expect((await dao.findByPhone('0501234567'))?.id, 'c2');
    });
  });

  group('the walk', () {
    test('stamps every row it writes with the walk that saw it', () async {
      final DateTime walk = testEpoch.add(const Duration(hours: 1));

      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: walk);

      expect((await dao.findById('c1'))?.seenAt, walk);
    });

    test('deletes only what the completed walk did not see', () async {
      final DateTime walk = testEpoch.add(const Duration(hours: 1));

      await dao.upsertAll(<CustomersCompanion>[
        _customer(),
        _customer(id: 'c2', name: 'Grace'),
      ], seenAt: testEpoch);
      // The walk sees one of them again.
      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: walk);

      expect(await dao.deleteUnseenSince(walk), 1);
      expect(await dao.findById('c1'), isNotNull);
      expect(await dao.findById('c2'), isNull);
    });
  });

  group('watchTags', () {
    test('flattens every tag in use, once each, in order', () async {
      await dao.upsertAll(<CustomersCompanion>[
        _customer(tags: '["vip","riyadh"]'),
        _customer(id: 'c2', name: 'Grace', tags: '["vip"]'),
      ], seenAt: testEpoch);

      expect(await dao.watchTags().first, <String>['riyadh', 'vip']);
    });

    test(
      'survives a column it cannot read rather than taking the screen down',
      () async {
        await dao.upsertAll(<CustomersCompanion>[
          _customer(tags: 'not json'),
        ], seenAt: testEpoch);

        expect(await dao.watchTags().first, isEmpty);
      },
    );
  });

  group('entries', () {
    CustomerNotesCompanion note({String id = 'n1', String body = 'Called'}) {
      return CustomerNotesCompanion.insert(
        id: id,
        customerId: 'c1',
        body: body,
        createdAt: testEpoch,
      );
    }

    setUp(() async {
      await dao.upsertAll(<CustomersCompanion>[_customer()], seenAt: testEpoch);
    });

    test('replaces one contact\'s entries wholesale', () async {
      await dao.replaceNotes('c1', <CustomerNotesCompanion>[note()]);
      await dao.replaceNotes('c1', <CustomerNotesCompanion>[
        note(id: 'n2', body: 'Called back'),
      ]);

      final List<CustomerNoteRow> rows = await dao.watchNotes('c1').first;

      expect(rows.single.id, 'n2');
    });

    test('orders them newest first', () async {
      await dao.replaceNotes('c1', <CustomerNotesCompanion>[]);
      await dao.insertNote(note());
      await dao.insertNote(
        CustomerNotesCompanion.insert(
          id: 'n2',
          customerId: 'c1',
          body: 'Later',
          createdAt: testEpoch.add(const Duration(hours: 1)),
        ),
      );

      final List<CustomerNoteRow> rows = await dao.watchNotes('c1').first;

      expect(rows.map((CustomerNoteRow row) => row.id), <String>['n2', 'n1']);
    });

    /*
      The cascade is declared on the table and enforced by the `PRAGMA` the
      migration strategy sets -- so a contact that goes takes its record with
      it rather than leaving rows nothing points at.
    */
    test('go with the contact they belong to', () async {
      await dao.insertNote(note());
      await dao.deleteById('c1');

      expect(await dao.watchNotes('c1').first, isEmpty);
    });
  });
}
