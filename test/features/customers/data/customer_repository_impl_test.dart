import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/customers/data/local/customer_dao.dart';
import 'package:tajeerai_mobile/features/customers/data/models/customer_dto.dart';
import 'package:tajeerai_mobile/features/customers/data/remote/customer_remote_data_source.dart';
import 'package:tajeerai_mobile/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:tajeerai_mobile/features/customers/domain/entities/customer.dart';
import 'package:tajeerai_mobile/features/customers/domain/entities/customer_note.dart';
import 'package:tajeerai_mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/network/http_client.dart';
import 'package:tajeerai_mobile/infrastructure/network/http_exception.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';

/// An HTTP client that answers from a script, so the repository is tested
/// against the shapes the API actually sends rather than against a fake
/// repository of its own.
class _ScriptedHttpClient implements HttpClient {
  _ScriptedHttpClient(this._answer);

  final Map<String, Object?> Function(String path) _answer;

  final List<String> calls = <String>[];

  @override
  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?>? query,
  }) async {
    calls.add(path);

    return _answer(path);
  }

  @override
  Future<Map<String, Object?>> post(String path, {Object? body}) async {
    calls.add(path);

    return _answer(path);
  }

  /// Every other verb is out of scope for these tests -- this client answers
  /// the two the customer endpoints use and nothing else.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _customerJson({
  String id = 'c1',
  String name = 'Ada Lovelace',
  String? phone = '+966 50 123 4567',
}) {
  return <String, Object?>{
    'id': id,
    'name': name,
    'phone': phone,
    'tags': <String>['vip'],
    'createdAt': testEpoch.toIso8601String(),
    'updatedAt': testEpoch.toIso8601String(),
  };
}

void main() {
  late AppDatabase database;
  late CustomerDao dao;

  setUp(() {
    database = openTestDatabase();
    dao = database.customerDao;
  });

  tearDown(() => database.close());

  CustomerRepositoryImpl repositoryFor(
    Map<String, Object?> Function(String path) answer,
  ) {
    return CustomerRepositoryImpl(
      dao: dao,
      remote: CustomerRemoteDataSource(_ScriptedHttpClient(answer)),
      clock: () => testEpoch,
    );
  }

  group('synchronizePage', () {
    /*
      The lookup keys are derived on the way in, in one place. A row written
      without them is a contact the caller card cannot find, and nothing later
      would notice.
    */
    test(
      'derives the phone lookup keys from the number the server sent',
      () async {
        final CustomerRepositoryImpl repository = repositoryFor(
          (_) => <String, Object?>{
            'data': <Object?>[_customerJson()],
            'meta': <String, Object?>{'lastPage': 1},
          },
        );

        await repository.synchronizePage(page: 1);

        final CustomerRow? row = await dao.findById('c1');

        expect(row?.phone, '+966 50 123 4567');
        expect(row?.phoneDigits, '966501234567');
        expect(row?.phoneSuffix, '501234567');
        expect(await repository.findByPhone('0501234567'), isNotNull);
      },
    );

    test('reports how far the walk can go from the envelope', () async {
      final CustomerRepositoryImpl repository = repositoryFor(
        (_) => <String, Object?>{
          'data': <Object?>[_customerJson()],
          'meta': <String, Object?>{'lastPage': 3},
        },
      );

      final CustomerPage page = await repository.synchronizePage(page: 1);

      expect(page.hasMore, isTrue);
      expect(page.lastPage, 3);
    });

    /*
      A server that says nothing about pages is read as "this was the last
      one". The alternative is a walk that never ends.
    */
    test(
      'stops when the server does not say how many pages there are',
      () async {
        final CustomerRepositoryImpl repository = repositoryFor(
          (_) => <String, Object?>{
            'data': <Object?>[_customerJson()],
          },
        );

        expect((await repository.synchronizePage(page: 2)).hasMore, isFalse);
      },
    );
  });

  group('failures', () {
    test(
      'translates a transport error into the app\'s own vocabulary',
      () async {
        final CustomerRepositoryImpl repository = repositoryFor(
          (_) => throw const HttpException(
            message: 'nope',
            isConnectionError: true,
          ),
        );

        await expectLater(
          repository.synchronizePage(page: 1),
          throwsA(isA<TransportFailure>()),
        );
      },
    );

    test(
      'translates a 404 into a not-found, which is what removes the row',
      () async {
        final CustomerRepositoryImpl repository = repositoryFor(
          (_) => throw const HttpException(message: 'gone', statusCode: 404),
        );

        await expectLater(
          repository.synchronizeNotes('c1'),
          throwsA(isA<NotFoundFailure>()),
        );
      },
    );

    /* An `HttpException` must never reach a caller above the data layer. */
    test('never lets a transport type escape', () async {
      final CustomerRepositoryImpl repository = repositoryFor(
        (_) => throw const HttpException(message: 'boom', statusCode: 500),
      );

      await expectLater(
        repository.searchOnline('ada'),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('notes', () {
    test('writes an added entry locally at once, without waiting for a sync', () async {
      final CustomerRepositoryImpl repository = repositoryFor(
        (String path) => path.endsWith('/notes')
            ? <String, Object?>{
                'id': 'n1',
                'subjectId': 'c1',
                'body': 'Called about the invoice.',
                'authorId': 'u1',
                'authorName': 'Demo Owner',
                'createdAt': testEpoch.toIso8601String(),
              }
            : <String, Object?>{
                'data': <Object?>[_customerJson()],
                'meta': <String, Object?>{'lastPage': 1},
              },
      );

      // The contact has to exist: `customer_notes` carries a real foreign key,
      // which is what stops an entry outliving the person it is about.
      await repository.synchronizePage(page: 1);

      final CustomerNote note = await repository.addNote('c1', 'Called');

      expect(note.authorName, 'Demo Owner');
      expect(
        (await repository.watchNotes('c1').first).single.body,
        'Called about the invoice.',
      );
    });

    test('replaces what it holds with what the server returned', () async {
      final CustomerRepositoryImpl repository = repositoryFor(
        (String path) => path.endsWith('/notes')
            ? <String, Object?>{
                'data': <Object?>[
                  <String, Object?>{
                    'id': 'n2',
                    'subjectId': 'c1',
                    'body': 'Newer',
                    'createdAt': testEpoch.toIso8601String(),
                  },
                ],
              }
            : <String, Object?>{
                'data': <Object?>[_customerJson()],
                'meta': <String, Object?>{'lastPage': 1},
              },
      );

      await repository.synchronizePage(page: 1);

      expect(await repository.synchronizeNotes('c1'), 1);
      expect((await repository.watchNotes('c1').first).single.id, 'n2');
    });
  });

  group('refresh', () {
    /*
      The online search hands over an id this device has never synced, and
      every screen past that point reads locally. Without this the contact
      opens as "removed from the workspace".
    */
    test(
      'brings a contact this device has never seen into local storage',
      () async {
        final CustomerRepositoryImpl repository = repositoryFor(
          (_) => _customerJson(id: 'c5', name: 'Grace'),
        );

        expect(await dao.findById('c5'), isNull);

        final Customer? fetched = await repository.refresh('c5');

        expect(fetched?.name, 'Grace');
        expect((await dao.findById('c5'))?.phoneSuffix, '501234567');
      },
    );

    test(
      'removes the local row when the server no longer has the contact',
      () async {
        final CustomerRepositoryImpl stored = repositoryFor(
          (_) => <String, Object?>{
            'data': <Object?>[_customerJson()],
            'meta': <String, Object?>{'lastPage': 1},
          },
        );
        await stored.synchronizePage(page: 1);

        final CustomerRepositoryImpl gone = repositoryFor(
          (_) => throw const HttpException(message: 'gone', statusCode: 404),
        );

        expect(await gone.refresh('c1'), isNull);
        expect(await dao.findById('c1'), isNull);
      },
    );

    /* Offline is not a deletion. The row has to survive a failed refresh. */
    test(
      'leaves the local row alone when the server could not be reached',
      () async {
        final CustomerRepositoryImpl stored = repositoryFor(
          (_) => <String, Object?>{
            'data': <Object?>[_customerJson()],
            'meta': <String, Object?>{'lastPage': 1},
          },
        );
        await stored.synchronizePage(page: 1);

        final CustomerRepositoryImpl offline = repositoryFor(
          (_) => throw const HttpException(
            message: 'nope',
            isConnectionError: true,
          ),
        );

        await expectLater(
          offline.refresh('c1'),
          throwsA(isA<TransportFailure>()),
        );
        expect(await dao.findById('c1'), isNotNull);
      },
    );
  });

  group('create', () {
    test('writes the created contact locally, keys and all', () async {
      final CustomerRepositoryImpl repository = repositoryFor(
        (_) => _customerJson(id: 'c9', name: 'Grace'),
      );

      final Customer created = await repository.create(
        name: 'Grace',
        phone: '0501234567',
      );

      expect(created.id, 'c9');
      expect((await dao.findById('c9'))?.phoneSuffix, '501234567');
    });
  });

  group('decoding', () {
    test('reads the type name out of the nested object', () {
      final Customer customer = CustomerDto.decode(<String, Object?>{
        ..._customerJson(),
        'type': <String, Object?>{'id': 't1', 'name': 'Wholesale'},
      });

      expect(customer.typeId, 't1');
      expect(customer.typeName, 'Wholesale');
    });

    /* The server's vocabulary grows; an unknown source is not a crash. */
    test('keeps a source it has never seen', () {
      final Customer customer = CustomerDto.decode(<String, Object?>{
        ..._customerJson(),
        'source': 'something_new',
      });

      expect(customer.source, 'something_new');
    });

    test('refuses a payload with no id rather than inventing one', () {
      expect(
        () => CustomerDto.decode(<String, Object?>{'name': 'Ada'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
