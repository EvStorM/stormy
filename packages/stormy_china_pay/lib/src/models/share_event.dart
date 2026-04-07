/// 分享事件基类
abstract class ShareEvent {
  /// 分享类型
  final String type;

  /// 是否成功
  final bool isSuccess;

  /// 错误码
  final String? errorCode;

  /// 错误信息
  final String? errorMessage;

  ShareEvent({
    required this.type,
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
  });
}
