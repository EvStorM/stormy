import '../models/auth_event.dart';
import '../models/payment_event.dart';
import '../models/share_event.dart';

/// 微信支付事件
class WeChatPaymentEvent extends PaymentEvent {
  WeChatPaymentEvent({
    required super.orderInfo,
    required super.isSuccess,
    super.errorCode,
    super.errorMessage,
  });
}

/// 微信分享事件
class WeChatShareEvent extends ShareEvent {
  WeChatShareEvent({
    required super.type,
    required super.isSuccess,
    super.errorCode,
    super.errorMessage,
  });
}

/// 微信授权事件
class WeChatAuthEvent extends AuthEvent {
  WeChatAuthEvent({
    required super.isSuccess,
    super.errorCode,
    super.errorMessage,
    super.authInfo,
  });
}

/// 微信小程序启动事件
class WeChatLaunchMiniProgramEvent {
  /// 订单信息
  final String? orderInfo;

  /// 是否成功
  final bool isSuccess;

  WeChatLaunchMiniProgramEvent({this.orderInfo, required this.isSuccess});
}
