import 'package:dio/dio.dart';

import '../../logging/logger.dart';

/// Records request outcomes.
///
/// Method, path and status only. Never headers -- that is where `Cookie` and
/// `Authorization` live -- and never bodies, which carry credentials on the
/// sign-in call and customer content everywhere else.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger);

  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug(
      '${options.method} ${options.path}',
      data: <String, Object?>{'baseUrl': options.baseUrl},
    );

    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug('${response.statusCode} ${response.requestOptions.path}');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err;
    _logger.warning(
      'request failed ${error.requestOptions.method} '
      '${error.requestOptions.path}',
      data: <String, Object?>{'type': error.type.name},
    );

    handler.next(err);
  }
}
