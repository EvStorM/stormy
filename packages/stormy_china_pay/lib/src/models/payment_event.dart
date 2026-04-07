/// 支付事件基类
abstract class PaymentEvent {
  /// 订单信息
  final String orderInfo;

  /// 是否成功
  final bool isSuccess;

  /// 是否是签约类型
  final bool isSignType;

  /// 错误码
  final String? errorCode;

  /// 错误信息
  final String? errorMessage;

  PaymentEvent({
    required this.orderInfo,
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    this.isSignType = false,
  });
}
