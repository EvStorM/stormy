/// 全局统一的网络异常基类
abstract class NetworkException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  NetworkException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'NetworkException [$statusCode]: $message';
}

/// HTTP/服务端 异常 (例如 404, 500)
class ServerException extends NetworkException {
  ServerException(super.message, {super.statusCode, super.data});
}

/// 客户端网络或连接异常 (超时, 断网)
class ConnectionException extends NetworkException {
  ConnectionException(super.message) : super(statusCode: -1);
}

/// 业务层异常 (HTTP 状态码 200，但业务 code 不等于 successCode)
class BusinessException extends NetworkException {
  BusinessException(super.message, {super.statusCode, super.data});
}

/// 授权异常 (例如 401 凭证失效)
class UnauthorizedException extends NetworkException {
  UnauthorizedException(super.message) : super(statusCode: 401);
}

/// 未知异常
class UnknownException extends NetworkException {
  UnknownException(super.message) : super(statusCode: -999);
}

/// 泛型数据投射/结构映射异常
class MappingException extends NetworkException {
  MappingException(super.message) : super(statusCode: -1000);
}
