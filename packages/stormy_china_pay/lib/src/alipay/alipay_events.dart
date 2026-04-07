import '../models/auth_event.dart';
import '../models/payment_event.dart';

/// 支付宝支付事件
class AlipayPaymentEvent extends PaymentEvent {
  /// 支付结果状态码
  final String? resultStatus;

  /// 支付结果消息
  final String? resultMessage;

  AlipayPaymentEvent({
    required super.orderInfo,
    required super.isSuccess,
    super.errorCode,
    super.errorMessage,
    super.isSignType,
    this.resultStatus,
    this.resultMessage,
  });
}

/// 支付宝授权事件
class AlipayAuthEvent extends AuthEvent {
  /// 授权订单信息
  final String? orderInfo;

  AlipayAuthEvent({
    required super.isSuccess,
    super.errorCode,
    super.errorMessage,
    super.authInfo,
    this.orderInfo,
  });
}
