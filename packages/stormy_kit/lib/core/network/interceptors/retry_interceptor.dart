import 'package:dio/dio.dart';

typedef RetryEvaluator = Future<bool> Function(DioException error, int attempt);

/// 请求重试拦截器
/// 当发生网络层错误进行有限策略重试
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final Duration retryInterval;
  final RetryEvaluator? evaluator;

  RetryInterceptor({
    required Dio dio,
    this.maxRetries = 2,
    this.retryInterval = const Duration(seconds: 2),
    this.evaluator,
  }) : _dio = dio;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    int attempt = extra['retry_attempt'] ?? 0;

    bool shouldRetry = _defaultEvaluator(err);

    if (evaluator != null) {
      // 允许外部定义业务层重试规则
      shouldRetry = await evaluator!(err, attempt);
    }

    if (shouldRetry && attempt < maxRetries) {
      attempt++;
      extra['retry_attempt'] = attempt;
      err.requestOptions.extra = extra;

      // 按照设定间隔后重试
      await Future.delayed(retryInterval);

      try {
        // 直接使用出错时的原始 request options，防止额外的属性挂载如 CancelToken, progress 等丢失
        final response = await _dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        // 重试依旧失败，抛向上层
        return handler.next(e);
      }
    }

    super.onError(err, handler);
  }

  /// 默认网络或连接异常才会重试，防止破坏业务（如 500 不建议立刻重传或者由于参数出错报 400）
  bool _defaultEvaluator(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    return false;
  }
}
