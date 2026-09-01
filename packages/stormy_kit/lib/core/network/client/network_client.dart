import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/network_config.dart';
import '../error/error_handler.dart';
import '../error/network_exception.dart';
import '../interceptors/auth_interceptor.dart';
import '../interceptors/logging_interceptor.dart';
import '../parser/data_parser.dart';
import '../parser/response_parser.dart';

/// Stormy 统一业务底层网络请求客户端
class StormyNetworkClient {
  late final Dio _dio;
  late final StormyNetworkConfig _config;
  late final AuthInterceptor _authInterceptor;

  // 统一的取消请求挂载池
  final Map<String, CancelToken> _cancelTokens = {};

  Dio get dio => _dio;

  /// 构造一个新的网络客户端实例，支持彻底的状态隔离
  StormyNetworkClient({required StormyNetworkConfig config}) {
    _config = config;

    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: config.headers,
      ),
    );

    // 初始化属于当前实例的鉴权拦截器
    _authInterceptor = AuthInterceptor();
    _dio.interceptors.add(_authInterceptor);

    // 自定义业务层拦截器
    final customInterceptors = config.interceptors;
    if (customInterceptors != null && customInterceptors.isNotEmpty) {
      _dio.interceptors.addAll(customInterceptors);
    }

    // 后置日志拦截引擎，保障拦截最外层的准确变化（需基于 talker 打印）
    if (config.enableLog) {
      _dio.interceptors.add(LoggingInterceptor.build());
    }

    // 判断是否强制跳过 HTTPS 证书校验
    if (config.skipCertificateVerification) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
  }

  /// 更新 BaseUrl 支持动态切服场景
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

  /// ================ 实例 Token 与 Header 配置 =================

  /// 配置 Token 完成，解锁当前客户端下被挂起等待 Token 的网络请求
  void completeGlobalToken({String? token, String? headerKey, String? prefix}) {
    _authInterceptor.completeToken(
      token: token,
      headerKey: headerKey,
      prefix: prefix,
    );
  }

  /// 配置 Header 完成，解锁当前客户端下被挂起等待 Header 的网络请求
  void completeGlobalHeader(Map<String, dynamic> headers) {
    _authInterceptor.completeHeader(headers);
  }

  /// 重置实例级别的鉴权配置状态
  void resetGlobalAuthConfig() {
    _authInterceptor.resetConfig();
  }

  /// ================ 请求取消挂载池 =================

  /// 取消指定 Tag 的请求
  void cancelByTag(String tag) {
    if (_cancelTokens.containsKey(tag)) {
      if (!_cancelTokens[tag]!.isCancelled) {
        _cancelTokens[tag]!.cancel('Cancelled by tag: $tag');
      }
      _cancelTokens.remove(tag);
    }
  }

  /// 取消当前客户端产生的所有被 Tag 管理的请求
  void cancelAll() {
    _cancelTokens.forEach((key, token) {
      if (!token.isCancelled) {
        token.cancel('Cancelled all requests');
      }
    });
    _cancelTokens.clear();
  }

  CancelToken _getOrCreateCancelToken(CancelToken? provided, String? tag) {
    final token = provided ?? CancelToken();
    if (tag != null) {
      final previous = _cancelTokens[tag];
      if (previous != null &&
          !identical(previous, token) &&
          !previous.isCancelled) {
        previous.cancel('Replaced by a newer request with tag: $tag');
      }
      _cancelTokens[tag] = token;
    }
    return token;
  }

  void _releaseCancelToken(String? tag, CancelToken token) {
    if (tag != null && identical(_cancelTokens[tag], token)) {
      _cancelTokens.remove(tag);
    }
  }

  Stream<T> _manageResponseStream<T>(
    Stream<T> source,
    String? tag,
    CancelToken token,
  ) {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;

    void release() => _releaseCancelToken(tag, token);

    controller = StreamController<T>(
      sync: true,
      onListen: () {
        subscription = source.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            release();
            controller.addError(
              ErrorHandler.handle(error, parsingConfig: _config.parsingConfig),
              stackTrace,
            );
          },
          onDone: () {
            release();
            unawaited(controller.close());
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        release();
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// ================ RESTful 请求核心能力封装 =================

  /// 发起保留原始响应体的流式请求。
  ///
  /// 该方法不会经过 [ResponseParser]，调用方可以直接消费
  /// [ResponseBody.stream] 并自行进行 SSE、NDJSON 等协议解帧。
  Future<Response<ResponseBody>> requestStream(
    String path, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool? requireToken,
    bool? requireHeader,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    try {
      final streamOptions =
          _ensureOptions(
            options?.copyWith(),
            requireToken,
            requireHeader,
          ).copyWith(
            method: method.toUpperCase(),
            responseType: ResponseType.stream,
          );

      final response = await dio.request<ResponseBody>(
        path,
        data: data,
        queryParameters: query,
        options: streamOptions,
        cancelToken: managedToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      final responseBody = response.data;
      if (responseBody != null) {
        responseBody.stream = _manageResponseStream(
          responseBody.stream,
          cancelTag,
          managedToken,
        );
      } else {
        _releaseCancelToken(cancelTag, managedToken);
      }

      return response;
    } catch (e) {
      _releaseCancelToken(cancelTag, managedToken);
      throw ErrorHandler.handle(e, parsingConfig: _config.parsingConfig);
    }
  }

  /// 发起 HTTP GET 请求
  Future<T> get<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    bool? requireToken,
    bool? requireHeader,
    DataParser<T>? parser,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    return _request(
      () => dio.get(
        path,
        queryParameters: query,
        data: data,
        options: _ensureOptions(options, requireToken, requireHeader),
        cancelToken: managedToken,
      ),
      parser: parser,
      cancelTag: cancelTag,
      managedToken: managedToken,
    );
  }

  /// 发起 HTTP POST 请求
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    bool? requireToken,
    bool? requireHeader,
    DataParser<T>? parser,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    return _request(
      () => dio.post(
        path,
        data: data,
        queryParameters: query,
        options: _ensureOptions(options, requireToken, requireHeader),
        cancelToken: managedToken,
      ),
      parser: parser,
      cancelTag: cancelTag,
      managedToken: managedToken,
    );
  }

  /// 发起 HTTP PUT 请求
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    bool? requireToken,
    bool? requireHeader,
    DataParser<T>? parser,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    return _request(
      () => dio.put(
        path,
        data: data,
        queryParameters: query,
        options: _ensureOptions(options, requireToken, requireHeader),
        cancelToken: managedToken,
      ),
      parser: parser,
      cancelTag: cancelTag,
      managedToken: managedToken,
    );
  }

  /// 发起 HTTP DELETE 请求
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    bool? requireToken,
    bool? requireHeader,
    DataParser<T>? parser,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    return _request(
      () => dio.delete(
        path,
        data: data,
        queryParameters: query,
        options: _ensureOptions(options, requireToken, requireHeader),
        cancelToken: managedToken,
      ),
      parser: parser,
      cancelTag: cancelTag,
      managedToken: managedToken,
    );
  }

  /// 大文件下载专线不走解包层拦截器，避免数据堆内存。
  Future<Response> download(
    String urlPath,
    dynamic savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    String? cancelTag,
    Options? options,
    bool? requireToken,
    bool? requireHeader,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    try {
      return await dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: managedToken,
        options: _ensureOptions(options, requireToken, requireHeader),
      );
    } catch (e) {
      throw ErrorHandler.handle(e, parsingConfig: _config.parsingConfig);
    } finally {
      _releaseCancelToken(cancelTag, managedToken);
    }
  }

  /// 多段组合表单及大文件上传
  Future<T> upload<T>(
    String path, {
    required dynamic data,
    Map<String, dynamic>? query,
    Options? options,
    CancelToken? cancelToken,
    String? cancelTag,
    ProgressCallback? onSendProgress,
    bool? requireToken,
    bool? requireHeader,
    DataParser<T>? parser,
  }) async {
    final managedToken = _getOrCreateCancelToken(cancelToken, cancelTag);
    return _request(
      () => dio.post(
        path,
        data: data,
        queryParameters: query,
        options: _ensureOptions(options, requireToken, requireHeader),
        cancelToken: managedToken,
        onSendProgress: onSendProgress,
      ),
      parser: parser,
      cancelTag: cancelTag,
      managedToken: managedToken,
    );
  }

  Options _ensureOptions(
    Options? options,
    bool? requireToken,
    bool? requireHeader,
  ) {
    final reqOptions = options ?? Options();
    reqOptions.extra ??= <String, dynamic>{};
    reqOptions.extra!['requireToken'] =
        requireToken ?? _config.defaultRequireToken;
    reqOptions.extra!['requireHeader'] =
        requireHeader ?? _config.defaultRequireHeader;
    return reqOptions;
  }

  /// 通用内部分发控制器与切面处理
  Future<T> _request<T>(
    Future<Response<dynamic>> Function() execution, {
    DataParser<T>? parser,
    String? cancelTag,
    required CancelToken managedToken,
  }) async {
    try {
      // 1. 发起底层的 Dio 调度
      final response = await execution();
      final body = response.data;

      // 2. 根据约定规范进行外壳包装去除，如分离业务层报错直接在此步抛出异常中断
      final dynamic rawBizData = ResponseParser.decode(
        body,
        _config.parsingConfig,
      );

      // 3. 进入用户自定义类型转换阶段
      if (parser != null && rawBizData != null) {
        return parser.parse(rawBizData);
      }

      // 如果未传递或者结构过于简单则强制默认返回，并增加针对类型的庇护抛出
      try {
        return rawBizData as T;
      } on TypeError {
        throw MappingException(
          '响应数据无法显式转换为强类型 $T, 当前实际类型为 ${rawBizData.runtimeType}',
        );
      }
    } catch (e) {
      // Dio层错误及我们预先抛出的业务错误会在包装后以安全、健壮和具备提示语的统一样貌出战
      throw ErrorHandler.handle(e, parsingConfig: _config.parsingConfig);
    } finally {
      _releaseCancelToken(cancelTag, managedToken);
    }
  }
}
