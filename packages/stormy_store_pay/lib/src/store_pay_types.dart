import 'dart:async';

import '../stormy_store_pay.dart';

// Re-export event classes and types
export 'store_pay_events.dart'
    show
        IAPPurchaseEvent,
        IAPPurchaseErrorEvent,
        PurchaseDetailsTransactionExtension;

/// 内购异常类
class StorePayException implements Exception {
  final String message;
  final PurchaseStatus? status;
  final Object? cause;

  StorePayException(this.message, {this.status, this.cause});

  bool get isCanceled => status == PurchaseStatus.canceled;

  @override
  String toString() {
    return 'StorePayException: $message${status != null ? ' (Status: $status)' : ''}';
  }
}


/// 内购状态枚举
enum IAPStatus { uninitialized, initializing, initialized, initializeFailed }

/// 平台类型枚举
enum IAPPlatform { google, apple, unsupported }

/// 购买生命周期状态
enum IAPPurchaseLifecycle { purchased, restored, pending }

typedef PurchaseVerifier =
    Future<bool> Function(PurchaseDetails purchaseDetails);

// ========== 统一抽象商品体系 ==========

/// 统一商品类型
enum StoreProductType {
  consumable,
  nonConsumable,
  subscription, // 对应 autoRenewable, nonRenewable 或 Google 的 sub
  unknown,
}

/// 统一计费周期单位
enum StorePeriodUnit { day, week, month, year, unknown }

/// 统一计费周期
class StorePeriod {
  final int value;
  final StorePeriodUnit unit;

  const StorePeriod({required this.value, required this.unit});

  @override
  String toString() {
    final String unitStr;
    switch (unit) {
      case StorePeriodUnit.day:
        unitStr = '天';
        break;
      case StorePeriodUnit.week:
        unitStr = '周';
        break;
      case StorePeriodUnit.month:
        unitStr = '个月';
        break;
      case StorePeriodUnit.year:
        unitStr = '年';
        break;
      case StorePeriodUnit.unknown:
        unitStr = '未知周期';
        break;
    }
    return '$value $unitStr';
  }
}

/// 统一价格信息
class StorePriceInfo {
  /// 实际金额 (e.g. 9.99)
  final double currentPrice;

  /// 原价 (e.g. 19.99) - 可选，用于展示优惠划线价
  final double? originalPrice;

  /// 本地化货币字符金额 (e.g. "$9.99" 或 "¥9.99")
  final String formattedPrice;

  /// 货币代码 (e.g. "USD", "CNY", "HKD")
  final String currencyCode;

  /// 货币符号 (e.g. "$", "¥")
  final String currencySymbol;

  /// 货币符号是否在价格前面 (e.g. $9.99 -> true, 9.99€ -> false)
  final bool symbolBeforePrice;

  /// 根据当前价格与周期计算出的日均价
  final double? pricePerDay;

  /// 根据当前价格与周期计算出的周均价 (基于 52周/年)
  final double? pricePerWeek;

  /// 根据当前价格与周期计算出的月均价 (基于 12月/年)
  final double? pricePerMonth;

  /// 根据当前价格与周期计算出的年均价 (基于 365天/年)
  final double? pricePerYear;

  const StorePriceInfo({
    required this.currentPrice,
    this.originalPrice,
    required this.formattedPrice,
    required this.currencyCode,
    required this.currencySymbol,
    this.symbolBeforePrice = true,
    this.pricePerDay,
    this.pricePerWeek,
    this.pricePerMonth,
    this.pricePerYear,
  });

  @override
  String toString() => '$formattedPrice ($currencyCode)';
}

/// 统一订阅优惠类型
enum StoreOfferType {
  freeTrial, // 免费试用
  introductory, // 首次购买特惠
  promotional, // 针对特定目标用户/条件优惠
  unknown,
}

/// 统一订阅及优惠支付模式
enum StorePaymentMode {
  payAsYouGo, // 分期支付当前优惠价
  payUpFront, // 预付全款
  freeTrial, // 免费
  unknown,
}

/// 统一优惠信息
class StoreOfferInfo {
  /// 优惠/阶段 ID 或者 Token
  final String id;
  final StoreOfferType type;
  final StorePriceInfo priceInfo;
  final StorePeriod period;
  final StorePaymentMode paymentMode;

  /// 该优惠适用的周期次数 (例如: 享受前3个月优惠 -> 3)
  final int paymentCount;

  const StoreOfferInfo({
    required this.id,
    required this.type,
    required this.priceInfo,
    required this.period,
    required this.paymentMode,
    required this.paymentCount,
  });
}

/// 统一订阅信息
class StoreSubscriptionInfo {
  /// 原生订阅组 ID（Apple 为 subscriptionGroupIdentifier，Google 通常即为 productId）
  final String groupId;

  /// 基本订阅周期
  final StorePeriod period;

  /// (Apple 特定) Apple 的订阅优惠列表
  final List<StoreOfferInfo>? applePromotionalOffers;

  /// (Google 特定) 对应的 Base Plan ID
  final String? googleBasePlanId;

  /// (Google 特定) Base Plan 的标签，用于在 UI 上决定是否标记“推荐”或“特惠”
  final List<String>? googleOfferTags;

  const StoreSubscriptionInfo({
    required this.groupId,
    required this.period,
    this.applePromotionalOffers,
    this.googleBasePlanId,
    this.googleOfferTags,
  });
}

/// 统一对外展示的可购买商品信息
///
/// 重要区别：
/// 在该封装模型中，此对象代表“一个可以展示在 UI 并进行购买的独立项”！
/// 对于 iOS，它通常与底层的 `SKProduct` 一一对应；
/// 对于 Android (Play Billing V5+) 的订阅，一个底层的 `ProductDetails` 会被 **扁平化** 展平为多个 `StoreProductInfo`，
/// 每个 `StoreProductInfo` 对应底层的一个 Base Plan。这样可以极大简化双平台兼容的 UI 编写。
class StoreProductInfo {
  /// 商品全局唯一标识。
  /// Apple 下通常为 productId；
  /// Google 普通商品下为 productId，Google 订阅商品下由于扁平化，格式约定为 `[productId]:[basePlanId]` 以区分。
  final String id;

  /// 原生商品 ID (Apple/Google 的 productId)
  final String nativeProductId;

  final String title;
  final String description;
  final StoreProductType type;
  final StorePriceInfo priceInfo;

  /// 只有订阅商品才会存在该字段
  final StoreSubscriptionInfo? subscriptionInfo;

  /// 与该商品或基础套餐绑定的各类优惠（包含新人首月减免、免费试用等）
  final List<StoreOfferInfo> offers;

  /// 底层原始数据，以备高级需求直接读取使用
  final ProductDetails rawDetails;

  /// (Google 特定) 购买当前基础套餐必备的凭证！如果没有则说明非订阅
  final String? googleDefaultOfferToken;

  const StoreProductInfo({
    required this.id,
    required this.nativeProductId,
    required this.title,
    required this.description,
    required this.type,
    required this.priceInfo,
    this.subscriptionInfo,
    this.offers = const [],
    required this.rawDetails,
    this.googleDefaultOfferToken,
  });

  /// 是否已经购买过（针对非消耗型和订阅型）。
  /// 自动判断：调用 `StorePayManager.instance.hasPurchased(nativeProductId)` 获取最新状态。
  bool get isPurchased {
    if (type == StoreProductType.nonConsumable ||
        type == StoreProductType.subscription) {
      return StorePayManager.instance.hasPurchased(nativeProductId);
    }
    return false;
  }

  bool get isSubscription => type == StoreProductType.subscription;

  /// 查找免费试用优惠（如果有）
  StoreOfferInfo? get freeTrialOffer {
    try {
      return offers.firstWhere(
        (o) =>
            o.type == StoreOfferType.freeTrial ||
            o.paymentMode == StorePaymentMode.freeTrial,
      );
    } catch (_) {
      return null;
    }
  }

  /// 查找特定优惠
  StoreOfferInfo? getOfferById(String offerId) {
    try {
      return offers.firstWhere((o) => o.id == offerId);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() {
    return 'StoreProductInfo(id: $id, title: $title, type: $type, price: ${priceInfo.formattedPrice}, offers: ${offers.length})';
  }
}
