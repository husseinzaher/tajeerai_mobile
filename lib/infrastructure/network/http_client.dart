import 'dart:io' show HttpDate;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../../app/config/app_config.dart';
import '../logging/logger.dart';
import 'http_exception.dart';
import 'interceptors/logging_interceptor.dart';
import 'token_refresher.dart';

/// The HTTP transport.
///
/// **HTTP is the secondary transport in this application.** It exists for the
/// operations the socket genuinely cannot carry, and every caller has to
/// justify itself:
///
/// - the sign-in exchange, because a socket handshake needs a token and the
///   token is what signing in produces -- there is no connection to send the
///   credentials over yet;
/// - session refresh and sign-out, for the same reason;
/// - file upload and download, which are streamed bodies, not frames.
///
/// Business reads and writes go over the socket. A new HTTP call for anything
/// else is an architectural decision that belongs in `ARCHITECTURE.md`, not a
/// convenience.
///
/// ## Cookies
///
/// The backend issues its session as `httpOnly` cookies (`tj_access`,
/// `tj_refresh`) and returns only `{user, tenant}` in the body -- it was built
/// for a browser. A [CookieJar] therefore captures the exchange, and
/// `AuthRemoteDataSource` reads the access cookie back out to hand to the
/// socket handshake, which accepts `auth.token`. That keeps the mobile client
/// working against the deployed API with no server change; see
/// `ARCHITECTURE.md` -> Backend assumptions.
///
/// ## An expired credential
///
/// A 401 on anything but the auth endpoints renews the session once, through
/// the same shared renewal the socket uses, and repeats the request. A second
/// 401 is the server's final word and reaches the caller as one.
class HttpClient {
  HttpClient._(
    this._dio,
    this.cookieJar, {
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
      renewCredential: renewCredential,
      onForbidden: onForbidden,
      clock: clock,
    );
  }

  final Dio _dio;

  /// Holds the session cookies. Read by the auth data source to recover the
  /// access token for the socket handshake.
  final CookieJar cookieJar;

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

  Future<Map<String, Object?>> get(String path, {Map<String, Object?>? query}) {
    return _send(path, () => _dio.get<Object?>(path, queryParameters: query));
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) {
    return _send(path, () => _dio.post<Object?>(path, data: body));
  }

  Future<Map<String, Object?>> patch(String path, {Object? body}) {
    return _send(path, () => _dio.patch<Object?>(path, data: body));
  }

  /// Sends a request and normalises everything that can go wrong into
  /// [HttpException].
  Future<Map<String, Object?>> _send(
    String path,
    Future<Response<Object?>> Function() request,
  ) async {
    Response<Object?> response = await _attempt(request);

    final Future<RefreshOutcome> Function()? renew = _renewCredential;

    if (response.statusCode == 401 &&
        renew != null &&
        !path.startsWith(_authPrefix)) {
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
