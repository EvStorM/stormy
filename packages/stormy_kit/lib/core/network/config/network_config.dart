import 'package:dio/dio.dart';

/// 网络配置类
class StormyNetworkConfig {
  /// 基础 URL
  final String baseUrl;

  /// 连接超时时间
  final Duration connectTimeout;

  /// 发送超时时间
  final Duration sendTimeout;

  /// 接收超时时间
  final Duration receiveTimeout;

  /// 默认请求头
  final Map<String, dynamic>? headers;

  /// 自定义拦截器列表
  final List<Interceptor>? interceptors;

  /// 是否启用日志
  final bool enableLog;

  /// 默认是否携带 Token（Opt-out 机制，默认为 true）
  final bool defaultRequireToken;

  /// 默认是否校验并注入全局 Header（默认为 true）
  final bool defaultRequireHeader;

  /// 统一响应解包配置（用于提取后端数据字段）
  /// 默认约定后端返回格式为 { "code": 0, "msg": "xx", "data": ... }
  final ResponseParsingConfig parsingConfig;

  StormyNetworkConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.headers,
    this.interceptors,
    this.enableLog = true,
    this.defaultRequireToken = true,
    this.defaultRequireHeader = true,
    ResponseParsingConfig? parsingConfig,
  }) : parsingConfig = parsingConfig ?? const ResponseParsingConfig();
}

/// 响应字段解析配置
class ResponseParsingConfig {
  /// 状态码字段名
  final String codeKey;

  /// 消息提示字段名
  final String messageKey;

  /// 真实数据字段名
  final String dataKey;

  /// 成功时的状态码值 (支持 int 或 String)
  final dynamic successCode;

  const ResponseParsingConfig({
    this.codeKey = 'code',
    this.messageKey = 'msg',
    this.dataKey = 'data',
    this.successCode = 0,
  });
}
