import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../../app/config/app_config.dart';
import '../logging/logger.dart';
import 'http_exception.dart';
import 'interceptors/logging_interceptor.dart';

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
class HttpClient {
  HttpClient._(this._dio, this.cookieJar);

  factory HttpClient.create({
    required AppConfig config,
    required Logger logger,
    required String userAgent,
    CookieJar? cookieJar,
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

    dio.interceptors
      ..add(CookieManager(jar))
      ..add(LoggingInterceptor(logger));

    return HttpClient._(dio, jar);
  }

  final Dio _dio;

  /// Holds the session cookies. Read by the auth data source to recover the
  /// access token for the socket handshake.
  final CookieJar cookieJar;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?>? query,
  }) async {
    return _send(() => _dio.get<Object?>(path, queryParameters: query));
  }

  Future<Map<String, Object?>> post(String path, {Object? body}) async {
    return _send(() => _dio.post<Object?>(path, data: body));
  }

  /// Sends a request and normalises everything that can go wrong into
  /// [HttpException].
  Future<Map<String, Object?>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    final Response<Object?> response;

    try {
      response = await request();
    } on DioException catch (error) {
      throw HttpException(
        message: 'Could not reach the server.',
        isConnectionError: true,
        cause: error,
      );
    }

    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      final data = response.data;

      // 204 and other empty successes are legitimate -- sign-out returns one.
      if (data == null) return const <String, Object?>{};
      if (data is Map<String, Object?>) return data;

      return <String, Object?>{'data': data};
    }

    throw HttpException(
      message: _messageFrom(response.data) ?? 'Request failed.',
      statusCode: status,
      body: response.data,
    );
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
