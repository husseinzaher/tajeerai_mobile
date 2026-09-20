import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/config/app_config.dart';
import 'package:TajeerAi/app/config/environment.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/network/http_client.dart';
import 'package:TajeerAi/infrastructure/network/http_exception.dart';
import 'package:TajeerAi/infrastructure/network/token_refresher.dart';

/// One scripted answer from the server.
typedef _Answer = ({
  int status,
  Object? body,
  Map<String, List<String>> headers,
});

_Answer _ok() => (
  status: 200,
  body: const <String, Object?>{'ok': true},
  headers: const <String, List<String>>{},
);

_Answer _status(
  int status, {
  Map<String, List<String>> headers = const <String, List<String>>{},
}) => (
  status: status,
  body: <String, Object?>{'message': 'status $status'},
  headers: headers,
);

/// Answers requests from a script -- an [_Answer] or the [DioExceptionType] to
/// fail with -- and records what was asked.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Object> script = <Object>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final Object next = script.removeAt(0);

    if (next is DioExceptionType) {
      throw DioException(requestOptions: options, type: next);
    }

    final _Answer answer = next as _Answer;

    return ResponseBody.fromString(
      jsonEncode(answer.body),
      answer.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        ...answer.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Renewer implements CredentialRenewer {
  _Renewer(this._renew);

  final Future<RefreshOutcome> Function() _renew;

  @override
  Future<RefreshOutcome> renew() => _renew();
}

HttpClient _client(
  _ScriptedAdapter adapter, {
  Future<RefreshOutcome> Function()? renew,
  void Function()? onForbidden,
}) {
  return HttpClient.create(
    config: const AppConfig(
      environment: Environment.development,
      apiBaseUrl: 'http://localhost',
      socketUrl: 'http://localhost',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      commandTimeout: Duration(seconds: 1),
    ),
    logger: Logger('test', verbose: false),
    userAgent: 'test',
    cookieJar: CookieJar(),
    renewCredential: renew,
    onForbidden: onForbidden,
    adapter: adapter,
    clock: () => DateTime.utc(2026, 9, 11, 12),
  );
}

/// The failure [call] throws, translated the way a repository would.
Future<AppFailure> _failureOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on HttpException catch (error) {
    return error.toFailure();
  }

  throw StateError('expected the call to fail');
}

void main() {
  group('an expired credential', () {
    test('renews once and repeats the request', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.addAll(<Object>[_status(401), _ok()]);
      int renewals = 0;
      final HttpClient client = _client(
        adapter,
        renew: () async {
          renewals += 1;

          return const TokenRefreshed('token-2');
        },
      );

      expect(await client.get('/v1/customers'), <String, Object?>{'ok': true});
      expect(renewals, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('a refused renewal reaches the caller as the 401 it was', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(_status(401));
      final HttpClient client = _client(
        adapter,
        renew: () async => const RefreshRejected(),
      );

      expect(
        await _failureOf(() => client.get('/v1/customers')),
        isA<AuthenticationFailure>(),
      );
      expect(adapter.requests, hasLength(1));
    });

    test('a second 401 after renewing is final', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.addAll(<Object>[_status(401), _status(401)]);
      int renewals = 0;
      final HttpClient client = _client(
        adapter,
        renew: () async {
          renewals += 1;

          return const TokenRefreshed('token-2');
        },
      );

      expect(
        await _failureOf(() => client.get('/v1/orders')),
        isA<AuthenticationFailure>(),
      );
      expect(renewals, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('the auth endpoints never renew on their own 401', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(_status(401));
      int renewals = 0;
      final HttpClient client = _client(
        adapter,
        renew: () async {
          renewals += 1;

          return const TokenRefreshed('token-2');
        },
      );

      await _failureOf(() => client.post('/v1/auth/refresh'));

      expect(renewals, 0);
    });

    test('two requests expiring together renew once', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.addAll(<Object>[_status(401), _status(401), _ok(), _ok()]);
      final Completer<RefreshOutcome> gate = Completer<RefreshOutcome>();
      int renewals = 0;
      final TokenRefresher refresher = TokenRefresher(
        _Renewer(() {
          renewals += 1;

          return gate.future;
        }),
      );
      final HttpClient client = _client(adapter, renew: refresher.refresh);

      final Future<Map<String, Object?>> customers = client.get(
        '/v1/customers',
      );
      final Future<Map<String, Object?>> orders = client.get('/v1/orders');
      await pumpEventQueue();
      gate.complete(const TokenRefreshed('token-2'));

      await Future.wait(<Future<Map<String, Object?>>>[customers, orders]);

      expect(renewals, 1);
      expect(adapter.requests, hasLength(4));
    });
  });

  group('answers that are not a fault in what was asked', () {
    test('a 403 is passed on, so permissions can be read again', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(_status(403));
      int told = 0;
      final HttpClient client = _client(adapter, onForbidden: () => told += 1);

      expect(
        await _failureOf(() => client.get('/v1/products')),
        isA<AuthorizationFailure>(),
      );
      expect(told, 1);
    });

    test('a 429 carries how long to wait, given in seconds', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(
          _status(
            429,
            headers: <String, List<String>>{
              'retry-after': <String>['30'],
            },
          ),
        );
      final HttpClient client = _client(adapter);

      expect(
        await _failureOf(() => client.get('/v1/customers')),
        isA<RateLimitedFailure>().having(
          (RateLimitedFailure failure) => failure.retryAfter,
          'retryAfter',
          const Duration(seconds: 30),
        ),
      );
    });

    test('or given as a date', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(
          _status(
            429,
            headers: <String, List<String>>{
              'retry-after': <String>['Fri, 11 Sep 2026 12:01:00 GMT'],
            },
          ),
        );
      final HttpClient client = _client(adapter);

      expect(
        await _failureOf(() => client.get('/v1/customers')),
        isA<RateLimitedFailure>().having(
          (RateLimitedFailure failure) => failure.retryAfter,
          'retryAfter',
          const Duration(minutes: 1),
        ),
      );
    });

    test('a slow server is a timeout, not "offline"', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(DioExceptionType.receiveTimeout);
      final HttpClient client = _client(adapter);

      expect(
        await _failureOf(() => client.get('/v1/orders')),
        isA<TransportFailure>().having(
          (TransportFailure failure) => failure.isOffline,
          'isOffline',
          isFalse,
        ),
      );
    });

    test('no connection at all is offline', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add(DioExceptionType.connectionError);
      final HttpClient client = _client(adapter);

      expect(
        await _failureOf(() => client.get('/v1/orders')),
        isA<TransportFailure>().having(
          (TransportFailure failure) => failure.isOffline,
          'isOffline',
          isTrue,
        ),
      );
    });
  });

  group('cookies', () {
    test('seeded cookies ride on the next request', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()..script.add(_ok());
      final HttpClient client = _client(adapter);

      await client.seedCookies(<String, String>{'tj_access': 'access-1'});
      await client.get('/v1/customers');

      expect(
        adapter.requests.single.headers['cookie'],
        contains('tj_access=access-1'),
      );
    });

    test('a cookie the server sets can be read back by name', () async {
      final _ScriptedAdapter adapter = _ScriptedAdapter()
        ..script.add((
          status: 200,
          body: const <String, Object?>{},
          headers: <String, List<String>>{
            'set-cookie': <String>['tj_access=access-2; Path=/; HttpOnly'],
          },
        ));
      final HttpClient client = _client(adapter);

      await client.post('/v1/auth/login');

      expect(await client.readCookies(), <String, String>{
        'tj_access': 'access-2',
      });
    });

    test('clearing forgets every cookie', () async {
      final HttpClient client = _client(_ScriptedAdapter());

      await client.seedCookies(<String, String>{'tj_refresh': 'refresh-1'});
      await client.clearCookies();

      expect(await client.readCookies(), isEmpty);
    });
  });

  test('patch sends a PATCH carrying its body', () async {
    final _ScriptedAdapter adapter = _ScriptedAdapter()..script.add(_ok());
    final HttpClient client = _client(adapter);

    await client.patch(
      '/v1/customers/c1',
      body: <String, Object?>{'name': 'Sara'},
    );

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.data, <String, Object?>{'name': 'Sara'});
  });
}
