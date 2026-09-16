/// Platform progress only. Entitlements must be confirmed by the business server.
enum PayStatus { launched, pending, platformSucceeded, cancelled, failed }

abstract class PaymentEvent {
  final String orderInfo;
  final PayStatus status;
  final bool isSignType;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => status == PayStatus.platformSucceeded;

  PaymentEvent({
    required this.orderInfo,
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.isSignType = false,
  });
}
