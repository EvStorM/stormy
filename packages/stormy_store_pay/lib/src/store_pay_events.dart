import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'store_pay_types.dart';

/// 内购事件定义
///
/// 包含购买成功、购买错误等事件的统一模型

/// 购买事件
///
/// 统一承载购买/恢复相关的信息
class IAPPurchaseEvent {
  /// 商品ID
  final String productId;

  /// 交易ID（平台原始订单号）
  final String? transactionId;

  /// 购买原始详情
  final PurchaseDetails details;

  /// 生命周期状态
  final IAPPurchaseLifecycle lifecycle;

  /// 是否为消耗型商品
  final bool isConsumable;

  /// 触发时间
  final DateTime occurredAt;

  const IAPPurchaseEvent({
    required this.productId,
    this.transactionId,
    required this.details,
    required this.lifecycle,
    required this.isConsumable,
    required this.occurredAt,
  });

  /// 是否属于恢复事件
  bool get isRestored => lifecycle == IAPPurchaseLifecycle.restored;

  /// 是否属于首次购买成功
  bool get isFirstPurchase => lifecycle == IAPPurchaseLifecycle.purchased;
}

/// 购买错误事件
class IAPPurchaseErrorEvent {
  /// 错误描述
  final String message;

  /// 关联的商品ID（可能为空）
  final String? productId;

  /// 对应的购买详情
  final PurchaseDetails? details;

  /// 原始状态
  final PurchaseStatus? purchaseStatus;

  /// 原始异常
  final Object? cause;

  /// 触发时间
  final DateTime occurredAt;

  IAPPurchaseErrorEvent({
    required this.message,
    this.productId,
    this.details,
    this.purchaseStatus,
    this.cause,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
}

/// PurchaseDetails 扩展，统一提取交易ID
extension PurchaseDetailsTransactionExtension on PurchaseDetails {
  /// 获取交易ID，优先返回平台原生订单号
  String? get transactionId {
    if (purchaseID != null && purchaseID!.isNotEmpty) {
      return purchaseID;
    }

    if (this is GooglePlayPurchaseDetails) {
      final orderId =
          (this as GooglePlayPurchaseDetails).billingClientPurchase.orderId;
      if (orderId.isNotEmpty) {
        return orderId;
      }
    }

    if (this is AppStorePurchaseDetails) {
      final transaction =
          (this as AppStorePurchaseDetails).skPaymentTransaction;
      final transactionId = transaction.transactionIdentifier;
      if (transactionId != null && transactionId.isNotEmpty) {
        return transactionId;
      }
    }

    return null;
  }
}
