import 'package:dio/dio.dart';
import '../config/network_config.dart';
import 'network_exception.dart';

/// 全局错误处理器
class ErrorHandler {
  /// 处理并将 [DioException] 转换成内部统一定义的 [NetworkException]
  static NetworkException handle(
    dynamic error, {
    ResponseParsingConfig? parsingConfig,
  }) {
    // 已经是经过转换或主动抛出的业务错误，直接透传
    if (error is NetworkException) {
      return error;
    }

    if (error is DioException) {
      final type = error.type;
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout) {
        return ConnectionException('网络请求超时，请检查网络环境');
      }

      if (type == DioExceptionType.connectionError) {
        return ConnectionException('未能连接到服务器，请检查设备连网状态');
      }

      if (type == DioExceptionType.badResponse) {
        final statusCode = error.response?.statusCode;
        final dynamic data = error.response?.data;
        final msg = _extractMessage(data, parsingConfig) ?? '服务器异常或未能响应正确结构';

        // 特殊身份校验
        if (statusCode == 401) {
          return UnauthorizedException('账号身份已过期或异常，请重新登录');
        }

        // 其他响应状态
        if (statusCode != null && statusCode >= 500) {
          return ServerException('服务器开小差了，请稍候再试', statusCode: statusCode);
        }
        return ServerException(
          '请求不被允许或发生异常 ($msg)',
          statusCode: statusCode,
          data: data,
        );
      }

      if (type == DioExceptionType.cancel) {
        return UnknownException('接口请求被主动拦截并取消');
      }

      if (type == DioExceptionType.badCertificate) {
        return ConnectionException('网络环境包含潜在风险，证书校验失败');
      }

      if (type == DioExceptionType.unknown) {
        return UnknownException('未知网络库错误: ${error.message ?? ''}');
      }

      // Dio 5.11 新增 transformTimeout；通过名称兼容旧版 Dio，避免
      // 在仍使用 5.9/5.10 的客户端中直接引用不存在的 enum member。
      if (type.name == 'transformTimeout') {
        return ConnectionException('网络响应解析超时，请稍后重试');
      }

      return UnknownException('未知网络库错误: ${error.message ?? ''}');
    }

    // fallback 到未知类型错误
    return UnknownException(error.toString());
  }

  /// 尽量去探测并提取服务端可能返回的错误 message (各种 JSON 写法不一)
  static String? _extractMessage(
    dynamic data,
    ResponseParsingConfig? parsingConfig,
  ) {
    if (data is Map<String, dynamic>) {
      if (parsingConfig != null && data.containsKey(parsingConfig.messageKey)) {
        return data[parsingConfig.messageKey]?.toString();
      }
      // 常见的不规范结构备选
      return data['message'] ??
          data['msg'] ??
          data['error_msg'] ??
          data['error'];
    }
    // 非 JSON 或纯文本可尝试转换处理
    return null;
  }
}
