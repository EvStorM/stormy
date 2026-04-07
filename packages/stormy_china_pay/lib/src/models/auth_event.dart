/// 授权事件基类
abstract class AuthEvent {
  /// 是否成功
  final bool isSuccess;

  /// 错误码
  final String? errorCode;

  /// 错误信息
  final String? errorMessage;

  /// 授权信息（JSON字符串或其他格式）
  final dynamic authInfo;

  AuthEvent({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    this.authInfo,
  });
}
