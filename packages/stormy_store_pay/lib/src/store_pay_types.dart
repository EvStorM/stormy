import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../stormy_store_pay.dart';

// Re-export event classes and types
export 'store_pay_events.dart'
    show
        IAPPurchaseEvent,
        IAPPurchaseErrorEvent,
        PurchaseDetailsTransactionExtension;

/// 内购状态枚举
enum IAPStatus {
  /// 未初始化
  uninitialized,

  /// 初始化中
  initializing,

  /// 已初始化
  initialized,

  /// 初始化失败
  initializeFailed,
}

/// 平台类型枚举
enum IAPPlatform {
  /// Google Play
  google,

  /// Apple App Store
  apple,

  /// 不支持的平台
  unsupported,
}

/// 购买生命周期状态
enum IAPPurchaseLifecycle {
  /// 首次购买成功
  purchased,

  /// 恢复历史购买
  restored,

  /// 处于等待完成状态
  pending,
}

/// 购买成功回调
typedef OnPurchaseSuccess = void Function(IAPPurchaseEvent event);

/// 购买错误回调
typedef OnPurchaseError = void Function(IAPPurchaseErrorEvent event);

/// 产品加载完成回调
typedef OnProductsLoaded = void Function(List<ProductDetails> products);

/// 购买恢复完成回调
typedef OnPurchaseRestored = void Function(IAPPurchaseEvent event);

/// 购买验证函数
typedef PurchaseVerifier =
    Future<bool> Function(PurchaseDetails purchaseDetails);

// ========== Google Play 特定类型 ==========

/// Google Play 订阅优惠信息
class SubscriptionOfferInfo {
  final String? offerId;
  final String basePlanId;
  final List<String> offerTags;
  final String offerToken;
  final List<PricingPhaseInfo> pricingPhases;
  final InstallmentPlanInfo? installmentPlanDetails;

  const SubscriptionOfferInfo({
    this.offerId,
    required this.basePlanId,
    required this.offerTags,
    required this.offerToken,
    required this.pricingPhases,
    this.installmentPlanDetails,
  });

  factory SubscriptionOfferInfo.fromWrapper(dynamic subscriptionOfferDetails) {
    return SubscriptionOfferInfo(
      offerId: subscriptionOfferDetails.offerId,
      basePlanId: subscriptionOfferDetails.basePlanId,
      offerTags: List<String>.from(subscriptionOfferDetails.offerTags),
      offerToken: subscriptionOfferDetails.offerIdToken,
      pricingPhases: (subscriptionOfferDetails.pricingPhases as List)
          .map((phase) => PricingPhaseInfo.fromWrapper(phase))
          .toList(),
      installmentPlanDetails:
          subscriptionOfferDetails.installmentPlanDetails != null
          ? InstallmentPlanInfo.fromWrapper(
              subscriptionOfferDetails.installmentPlanDetails,
            )
          : null,
    );
  }

  bool get isBasePlan => offerId == null;
  bool get hasFreeTrial =>
      pricingPhases.isNotEmpty && pricingPhases.first.priceAmountMicros == 0;
  bool get hasIntroductoryPrice => pricingPhases.length > 1;

  @override
  String toString() {
    return 'SubscriptionOfferInfo('
        'offerId: $offerId, '
        'basePlanId: $basePlanId, '
        'offerTags: $offerTags, '
        'offerToken: $offerToken, '
        'pricingPhases: ${pricingPhases.length}, '
        'installmentPlanDetails: $installmentPlanDetails'
        ')';
  }
}

/// 定价阶段信息
class PricingPhaseInfo {
  final String formattedPrice;
  final String priceCurrencyCode;
  final int priceAmountMicros;
  final int billingCycleCount;
  final String billingPeriod;
  final int recurrenceMode;

  const PricingPhaseInfo({
    required this.formattedPrice,
    required this.priceCurrencyCode,
    required this.priceAmountMicros,
    required this.billingCycleCount,
    required this.billingPeriod,
    required this.recurrenceMode,
  });

  factory PricingPhaseInfo.fromWrapper(dynamic pricingPhase) {
    final recurrenceModeValue = pricingPhase.recurrenceMode is int
        ? pricingPhase.recurrenceMode
        : (pricingPhase.recurrenceMode.index + 1);

    return PricingPhaseInfo(
      formattedPrice: pricingPhase.formattedPrice,
      priceCurrencyCode: pricingPhase.priceCurrencyCode,
      priceAmountMicros: pricingPhase.priceAmountMicros,
      billingCycleCount: pricingPhase.billingCycleCount,
      billingPeriod: pricingPhase.billingPeriod,
      recurrenceMode: recurrenceModeValue,
    );
  }

  double get price => priceAmountMicros / 1000000.0;
  bool get isFree => priceAmountMicros == 0;
  bool get isInfiniteRecurring => recurrenceMode == 2;
  bool get isFiniteRecurring => recurrenceMode == 1 && billingCycleCount > 0;

  @override
  String toString() {
    return 'PricingPhaseInfo('
        'formattedPrice: $formattedPrice, '
        'priceCurrencyCode: $priceCurrencyCode, '
        'priceAmountMicros: $priceAmountMicros, '
        'billingCycleCount: $billingCycleCount, '
        'billingPeriod: $billingPeriod, '
        'recurrenceMode: $recurrenceMode'
        ')';
  }
}

/// 分期付款计划信息
class InstallmentPlanInfo {
  final int commitmentPaymentsCount;
  final int subsequentCommitmentPaymentsCount;

  const InstallmentPlanInfo({
    required this.commitmentPaymentsCount,
    required this.subsequentCommitmentPaymentsCount,
  });

  factory InstallmentPlanInfo.fromWrapper(dynamic installmentPlanDetails) {
    return InstallmentPlanInfo(
      commitmentPaymentsCount:
          installmentPlanDetails.commitmentPaymentsCount ?? 0,
      subsequentCommitmentPaymentsCount:
          installmentPlanDetails.subsequentCommitmentPaymentsCount ?? 0,
    );
  }

  @override
  String toString() {
    return 'InstallmentPlanInfo('
        'commitmentPaymentsCount: $commitmentPaymentsCount, '
        'subsequentCommitmentPaymentsCount: $subsequentCommitmentPaymentsCount'
        ')';
  }
}

// ========== Apple 特定类型 ==========

/// Apple 平台商品类型
enum AppleProductType {
  consumable,
  nonConsumable,
  nonRenewable,
  autoRenewable,
  unknown,
}

/// Apple 平台订阅优惠类型
enum AppleSubscriptionOfferType { introductory, promotional, winBack, unknown }

/// Apple 平台订阅优惠扣费模式
enum AppleSubscriptionOfferPaymentMode {
  payAsYouGo,
  payUpFront,
  freeTrial,
  unknown,
}

/// Apple 平台订阅周期单位
enum AppleSubscriptionPeriodUnit { day, week, month, year, unknown }

/// Apple 平台订阅周期信息
class AppleSubscriptionPeriodInfo {
  final int value;
  final AppleSubscriptionPeriodUnit unit;

  const AppleSubscriptionPeriodInfo({required this.value, required this.unit});
}

/// Apple 平台订阅优惠信息
class AppleSubscriptionOfferInfo {
  final String? id;
  final double price;
  final AppleSubscriptionOfferType type;
  final AppleSubscriptionPeriodInfo period;
  final int periodCount;
  final AppleSubscriptionOfferPaymentMode paymentMode;

  const AppleSubscriptionOfferInfo({
    required this.id,
    required this.price,
    required this.type,
    required this.period,
    required this.periodCount,
    required this.paymentMode,
  });
}

/// Apple 平台订阅详情
class AppleSubscriptionInfo {
  final String subscriptionGroupId;
  final AppleSubscriptionPeriodInfo subscriptionPeriod;
  final List<AppleSubscriptionOfferInfo> promotionalOffers;

  const AppleSubscriptionInfo({
    required this.subscriptionGroupId,
    required this.subscriptionPeriod,
    required this.promotionalOffers,
  });
}

/// Apple 平台商品详情
class AppleProductInfo {
  final String productId;
  final String title;
  final String description;
  final String displayPrice;
  final double rawPrice;
  final String currencyCode;
  final String currencySymbol;
  final AppleProductType productType;
  final AppleSubscriptionInfo? subscriptionInfo;

  const AppleProductInfo({
    required this.productId,
    required this.title,
    required this.description,
    required this.displayPrice,
    required this.rawPrice,
    required this.currencyCode,
    required this.currencySymbol,
    required this.productType,
    this.subscriptionInfo,
  });
}
