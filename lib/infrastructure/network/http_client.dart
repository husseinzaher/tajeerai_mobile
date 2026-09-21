import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:http_parser/http_parser.dart';

import '../../app/config/app_config.dart';
import '../logging/logger.dart';
import 'http_exception.dart';
import 'interceptors/logging_interceptor.dart';
import 'token_refresher.dart';

/// The HTTP transport.
///
/// **HTTP is the secondary transport in this application.** It carries what
/// `ARCHITECTURE.md` §11 lists, and nothing else:
///
/// - the sign-in exchange, because a socket handshake needs a token and the
///   token is what signing in produces -- there is no connection to send the
///   credentials over yet;
/// - session refresh and sign-out, for the same reason;
/// - file upload and download, which are streamed bodies, not frames;
/// - the workspace data the socket does not expose -- customers, orders and
///   products -- which sync into the local database like everything else.
///
/// Anything more is an architectural decision that belongs in §11 first.
/// RULE 36 keeps every caller in a feature's `data/remote/`, where that
/// decision can be reviewed.
///
/// ## Cookies
///
/// The backend issues its session as `httpOnly` cookies (`tj_access`,
/// `tj_refresh`) and returns only `{user, tenant}` in the body -- it was built
/// for a browser. A [CookieJar] therefore captures the exchange, and
/// `AuthRemoteDataSource` reads the access cookie back out through
/// [readCookies] to hand to the socket handshake, which accepts `auth.token`.
/// That keeps the mobile client working against the deployed API with no
/// server change; see `ARCHITECTURE.md` -> Backend assumptions.
///
/// ## An expired credential
///
/// A 401 on anything but the auth endpoints renews the session once, through
/// the same shared renewal the socket uses, and repeats the request. A second
/// 401 is the server's final word and reaches the caller as one.
class HttpClient {
  HttpClient._(
    this._dio,
    this._cookieJar,
    this._cookieOrigin, {
    required Future<RefreshOutcome> Function()? renewCredential,
    required void Function()? onForbidden,
    required DateTime Function() clock,
  }) : _renewCredential = renewCredential,
       _onForbidden = onForbidden,
       _clock = clock;

  factory HttpClient.create({
    required AppConfig config,
    required Logger logger,
    required String userAgent,
    CookieJar? cookieJar,
    Future<RefreshOutcome> Function()? renewCredential,
    void Function()? onForbidden,
    HttpClientAdapter? adapter,
    DateTime Function() clock = DateTime.now,
  }) {
    final jar = cookieJar ?? CookieJar();

    final dio = Dio(
      BaseOptions(
        // Origin plus the backend's global prefix -- see AppConfig.apiRoot.
        baseUrl: config.apiRoot,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        headers: <String, Object?>{
          'Accept': 'application/json',
          'User-Agent': userAgent,
        },
        // Non-2xx is handled by this class rather than thrown by Dio, so the
        // status-to-failure mapping lives in exactly one place.
        validateStatus: (_) => true,
        responseType: ResponseType.json,
      ),
    );

    // Only tests supply one: it answers without a network.
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors
      ..add(CookieManager(jar))
      ..add(LoggingInterceptor(logger));

    return HttpClient._(
      dio,
      jar,
      Uri.parse(config.apiBaseUrl),
      renewCredential: renewCredential,
      onForbidden: onForbidden,
      clock: clock,
    );
  }

  final Dio _dio;

  /// Holds the session cookies between requests.
  final CookieJar _cookieJar;

  /// Where the session cookies are scoped: the API's origin.
  final Uri _cookieOrigin;

  /// Renews the session when a request comes back 401.
  ///
  /// A closure supplied by the composition root rather than an object, because
  /// what renews a session is itself built on this client.
  final Future<RefreshOutcome> Function()? _renewCredential;

  /// Told when the server answers 403: the member's permissions may have
  /// changed since the session was last read.
  final void Function()? _onForbidden;

  final DateTime Function() _clock;

  /// The auth endpoints manage the credential themselves. Renewing on their
  /// 401 would have a failed sign-in, refresh or sign-out try to renew itself.
  static const String _authPrefix = '/v1/auth/';

  /// The blog is public, so a 401 from it is an answer rather than a stale token.
  ///
  /// Renewal has a consequence: a refusal signs the member out. That is right
  /// for workspace data, where a rejected refresh means the session is over,
  /// and wrong for an article a guest is reading - they may have no session at
  /// all, and the one thing a public read must never do is end somebody's.
  static const String _publicPrefix = '/v1/blog/public/';

  /// Whether a 401 on this path should be treated as a stale credential.
  static bool _renewable(String path) =>
      !path.startsWith(_authPrefix) && !path.startsWith(_publicPrefix);

  Future<Map<String, Object?>> get(String path, {Map<String, Object?>? query}) {
    return _send(path, () => _dio.get<Object?>(path, queryParameters: query));
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) {
    return _send(path, () => _dio.post<Object?>(path, data: body));
  }

  Future<Map<String, Object?>> patch(String path, {Object? body}) {
    return _send(path, () => _dio.patch<Object?>(path, data: body));
  }

  /// Multipart upload for a single file field.
  ///
  /// Used for conversation media (`POST /v1/conversations/:id/media`). The
  /// backend expects the field name `file`, matching the web inbox composer.
  Future<Map<String, Object?>> postMultipart(
    String path, {
    required String filePath,
    required String filename,
    String? mimeType,
    String fieldName = 'file',
    Duration? sendTimeout,
    Duration? receiveTimeout,
  }) {
    return _send(path, () async {
      final formData = FormData.fromMap(<String, Object?>{
        fieldName: await MultipartFile.fromFile(
          filePath,
          filename: filename,
          contentType: mimeType == null ? null : MediaType.parse(mimeType),
        ),
      });

      return _dio.post<Object?>(
        path,
        data: formData,
        options: Options(
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );
    });
  }

  /// Downloads a binary body, such as a message attachment.
  Future<Uint8List> getBytes(String path) async {
    Response<Object?> response = await _attempt(
      () => _dio.get<Object?>(
        path,
        options: Options(responseType: ResponseType.bytes),
      ),
    );

    final Future<RefreshOutcome> Function()? renew = _renewCredential;

    if (response.statusCode == 401 && renew != null && _renewable(path)) {
      if (await renew() is TokenRefreshed) {
        response = await _attempt(
          () => _dio.get<Object?>(
            path,
            options: Options(responseType: ResponseType.bytes),
          ),
        );
      }
    }

    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      final data = response.data;

      if (data is Uint8List) return data;
      if (data is List<int>) return Uint8List.fromList(data);

      return Uint8List(0);
    }

    if (status == 403) _onForbidden?.call();

    throw HttpException(
      message: _messageFrom(response.data) ?? 'Request failed.',
      statusCode: status,
      body: response.data,
      retryAfter: status == 429 ? _retryAfter(response.headers) : null,
    );
  }

  /// The absolute URL a relative API path resolves to.
  ///
  /// For the one flow that hands a URL to something other than this client:
  /// a social sign-in opens in the system browser, and the browser needs the
  /// whole address. Built from the same base every request uses, so it cannot
  /// drift from the environment the app is pointed at.
  Uri resolve(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse('${_dio.options.baseUrl}$path');

    return query == null || query.isEmpty
        ? base
        : base.replace(
            queryParameters: <String, String>{
              ...base.queryParameters,
              ...query,
            },
          );
  }

  /// The absolute URL an **origin-rooted** path resolves to.
  ///
  /// Distinct from [resolve], and the distinction is the whole point of having
  /// two. [resolve] completes a path this client would request, so it is
  /// relative to the API root — origin *plus* the backend's global `/api`
  /// prefix. A path that arrives inside stored content already carries that
  /// prefix, because the website serves the API and its own pages from one
  /// origin and a media address is saved as `/api/v1/media/public/<id>`.
  ///
  /// Completing one of those against the API root produces `…/api/api/v1/…`,
  /// which 404s — every cover image on the blog was a broken-image box until
  /// this existed.
  Uri resolveFromOrigin(String path) => _cookieOrigin.resolve(path);

  /// Puts cookies back in the jar, by name and value.
  ///
  /// The jar lives in memory, so a cold start has none, and every request
  /// would 401 even though the tokens survived in secure storage.
  Future<void> seedCookies(Map<String, String> cookies) async {
    if (cookies.isEmpty) return;

    await _cookieJar.saveFromResponse(_cookieOrigin, <Cookie>[
      for (final MapEntry<String, String> cookie in cookies.entries)
        Cookie(cookie.key, cookie.value)..path = '/',
    ]);
  }

  /// The cookies the next request to the API would carry, by name.
  Future<Map<String, String>> readCookies() async {
    final List<Cookie> cookies = await _cookieJar.loadForRequest(_cookieOrigin);

    return <String, String>{
      for (final Cookie cookie in cookies) cookie.name: cookie.value,
    };
  }

  Future<void> clearCookies() => _cookieJar.deleteAll();

  /// Sends a request and normalises everything that can go wrong into
  /// [HttpException].
  Future<Map<String, Object?>> _send(
    String path,
    Future<Response<Object?>> Function() request,
  ) async {
    Response<Object?> response = await _attempt(request);

    final Future<RefreshOutcome> Function()? renew = _renewCredential;

    if (response.statusCode == 401 && renew != null && _renewable(path)) {
      // Once. The retry carries the renewed cookie from the jar.
      if (await renew() is TokenRefreshed) {
        response = await _attempt(request);
      }
    }

    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      final data = response.data;

      // 204 and other empty successes are legitimate -- sign-out returns one.
      if (data == null) return const <String, Object?>{};
      if (data is Map<String, Object?>) return data;

      return <String, Object?>{'data': data};
    }

    if (status == 403) _onForbidden?.call();

    throw HttpException(
      message: _messageFrom(response.data) ?? 'Request failed.',
      statusCode: status,
      body: response.data,
      retryAfter: status == 429 ? _retryAfter(response.headers) : null,
    );
  }

  /// Runs one request, turning Dio's failures into [HttpException].
  Future<Response<Object?>> _attempt(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw switch (error.type) {
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => HttpException(
          message: 'The server took too long to answer.',
          isTimeout: true,
          cause: error,
        ),
        DioExceptionType.badCertificate => HttpException(
          message: "The server's certificate was not accepted.",
          cause: error,
        ),
        _ => HttpException(
          message: 'Could not reach the server.',
          isConnectionError: true,
          cause: error,
        ),
      };
    }
  }

  /// `Retry-After` is either a number of seconds or an HTTP date.
  Duration? _retryAfter(Headers headers) {
    final String? value = headers.value('retry-after');
    if (value == null) return null;

    final int? seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);

    try {
      final Duration wait = HttpDate.parse(value).difference(_clock());

      return wait.isNegative ? Duration.zero : wait;
    } on Exception {
      return null;
    }
  }

  /// Nest reports failures as `{ message: string | string[] }`.
  static String? _messageFrom(Object? body) {
    if (body is! Map) return null;

    final message = body['message'];

    return switch (message) {
      final String text => text,
      final List<Object?> list when list.isNotEmpty => list.first.toString(),
      _ => null,
    };
  }
}
