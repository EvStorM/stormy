import 'dart:async';

import 'package:dio/dio.dart';
import 'package:stormy_core/stormy_core.dart';

typedef OnUnauthorized = Future<void> Function(DioException error);

/// 鉴权与动态头拦截器
/// 负责全局的 Token 和 Header 分发管理，支持异步等待直至配置完成才发起请求
class AuthInterceptor extends Interceptor {
  // 实例级的状态标识
  bool isTokenConfigured = false;
  bool isHeaderConfigured = false;

  String? _token;
  String _tokenHeaderKey = 'Authorization';
  String _tokenPrefix = 'Bearer ';

  final Map<String, dynamic> _headers = {};

  final List<Completer<void>> _tokenWaiters = [];
  final List<Completer<void>> _headerWaiters = [];

  final OnUnauthorized? onUnauthorized;

  AuthInterceptor({this.onUnauthorized});

  /// 外部配置 Token 完成调用此接口，解除拦截器的等待状态
  void completeToken({String? token, String? headerKey, String? prefix}) {
    if (token != null) _token = token;
    if (headerKey != null) _tokenHeaderKey = headerKey;
    if (prefix != null) _tokenPrefix = prefix;

    isTokenConfigured = true;
    for (var completer in _tokenWaiters) {
      if (!completer.isCompleted) completer.complete();
    }
    _tokenWaiters.clear();
  }

  /// 外部配置 Header 完成调用此接口，解除拦截器的等待状态
  void completeHeader(Map<String, dynamic> headers) {
    _headers.addAll(headers);
    isHeaderConfigured = true;
    for (var completer in _headerWaiters) {
      if (!completer.isCompleted) completer.complete();
    }
    _headerWaiters.clear();
  }

  /// 重新复位配置状态 (用于退出登录等场景)
  void resetConfig() {
    isTokenConfigured = false;
    isHeaderConfigured = false;
    _token = null;
    _headers.clear();
  }

  Future<void> _waitForToken(CancelToken? cancelToken) async {
    if (isTokenConfigured) return;
    final completer = Completer<void>();
    _tokenWaiters.add(completer);
    try {
      await _waitForConfiguration(completer, cancelToken);
    } finally {
      _tokenWaiters.remove(completer);
    }
  }

  Future<void> _waitForHeader(CancelToken? cancelToken) async {
    if (isHeaderConfigured) return;
    final completer = Completer<void>();
    _headerWaiters.add(completer);
    try {
      await _waitForConfiguration(completer, cancelToken);
    } finally {
      _headerWaiters.remove(completer);
    }
  }

  Future<void> _waitForConfiguration(
    Completer<void> configured,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await configured.future;
      return;
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    final outcome = await Future.any<Object?>([
      configured.future.then<Object?>((_) => null),
      cancelToken.whenCancel.then<Object?>((error) => error),
    ]);
    if (outcome is DioException) throw outcome;
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // 检查此接口是否需要 Header 设置
      final requireHeader = options.extra['requireHeader'] == true;
      if (requireHeader) {
        await _waitForHeader(options.cancelToken);
        // 在全局 Header 中添加，但不覆盖单次请求已显式指定的同名 Header
        _headers.forEach((key, value) {
          if (!options.headers.containsKey(key)) {
            options.headers[key] = value;
          }
        });
      }

      // 检查此接口是否需要 Token 设置
      final requireToken = options.extra['requireToken'] == true;
      if (requireToken) {
        await _waitForToken(options.cancelToken);
        if (_token != null && _token!.isNotEmpty) {
          // 如果接口自己没有带 token header，再使用全局 token
          if (!options.headers.containsKey(_tokenHeaderKey)) {
            options.headers[_tokenHeaderKey] = '$_tokenPrefix$_token';
          }
        }
      }

      handler.next(options);
    } on DioException catch (error) {
      handler.reject(error);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      if (onUnauthorized != null) {
        await onUnauthorized!(err);
      }
    }
    handler.next(err);
  }
}
