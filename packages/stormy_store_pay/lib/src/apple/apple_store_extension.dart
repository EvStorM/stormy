import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

import '../store_pay_base.dart';
import '../store_pay_types.dart';

/// Apple App Store 平台扩展
///
/// 提供 Apple Store 特有的功能
class AppleStoreExtension implements IAPPlatformExtension {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  AppleStoreExtension();

  @override
  IAPPlatform get platform => IAPPlatform.apple;

  @override
  bool get isAvailable => true; // 实际检查由上层 Manager 处理

  /// 注册商品类型，便于正确区分消耗型/订阅等分类
  void registerProductTypes(Map<String, AppleProductType> productTypes) {
    // 由 AppleStoreManager 处理
  }

  /// 查询 Apple 平台特有的商品信息（包含 StoreKit 2 元数据）
  Future<List<AppleProductInfo>> queryAppleProductInfos(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return [];

    return _performQueryAppleProductInfos(productIds);
  }

  Future<List<AppleProductInfo>> _performQueryAppleProductInfos(
    List<String> productIds,
  ) async {
    try {
      final response = await _inAppPurchase.queryProductDetails(
        productIds.toSet(),
      );

      if (response.error != null || response.productDetails.isEmpty) {
        return [];
      }

      final infos = response.productDetails
          .map(_buildAppleProductInfo)
          .whereType<AppleProductInfo>()
          .toList();

      debugPrint('[Apple Store Extension] 已加载 ${infos.length} 个 Apple 商品详情');
      return infos;
    } catch (e) {
      debugPrint('[Apple Store Extension] 查询商品信息异常: $e');
      return [];
    }
  }

  /// 带数量的购买（iOS特定）
  Future<bool> purchaseWithQuantity(
    ProductDetails productDetails, {
    int quantity = 1,
    String? applicationUsername,
  }) async {
    if (quantity < 1) return false;

    return _performPurchaseWithQuantity(
      productDetails,
      quantity: quantity,
      applicationUsername: applicationUsername,
    );
  }

  Future<bool> _performPurchaseWithQuantity(
    ProductDetails productDetails, {
    required int quantity,
    String? applicationUsername,
  }) async {
    try {
      final purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUsername,
      );

      debugPrint(
        '[Apple Store Extension] 购买产品: ${productDetails.id}, 数量: $quantity',
      );

      for (int i = 0; i < quantity; i++) {
        final result = await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
        if (!result) {
          debugPrint('[Apple Store Extension] 第 ${i + 1} 次购买失败');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Apple Store Extension] 购买失败: $e');
      return false;
    }
  }

  /// 获取订阅优惠列表
  Future<List<SK2SubscriptionOffer>> getSubscriptionOffers(String productId) async {
    return _performGetSubscriptionOffers(productId);
  }

  Future<List<SK2SubscriptionOffer>> _performGetSubscriptionOffers(
    String productId,
  ) async {
    try {
      final response = await _inAppPurchase.queryProductDetails({productId});

      if (response.error != null || response.productDetails.isEmpty) {
        return [];
      }

      final productDetails = response.productDetails.first;
      if (productDetails is! AppStoreProduct2Details) {
        return [];
      }

      final subscriptionInfo = productDetails.sk2Product.subscription;
      if (subscriptionInfo == null) {
        return [];
      }

      final offers = subscriptionInfo.promotionalOffers.toList();
      debugPrint('[Apple Store Extension] 找到 ${offers.length} 个订阅优惠');
      return offers;
    } catch (e) {
      debugPrint('[Apple Store Extension] 查询订阅优惠失败: $e');
      return [];
    }
  }

  /// 使用优惠购买产品
  Future<bool> purchaseWithOffer(
    ProductDetails productDetails,
    SK2SubscriptionOffer offer, {
    SK2SubscriptionOfferSignature? signature,
  }) async {
    return _performPurchaseWithOffer(
      productDetails,
      offer,
      signature: signature,
    );
  }

  Future<bool> _performPurchaseWithOffer(
    ProductDetails productDetails,
    SK2SubscriptionOffer offer, {
    SK2SubscriptionOfferSignature? signature,
  }) async {
    try {
      final purchaseParam = Sk2PurchaseParam.fromOffer(
        productDetails: productDetails,
        offer: offer,
        signature: signature,
      );

      debugPrint('[Apple Store Extension] 使用订阅优惠购买: ${productDetails.id}');
      debugPrint('[Apple Store Extension] 优惠ID: ${offer.id}');

      final result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!result) {
        return false;
      }

      debugPrint('[Apple Store Extension] 购买请求已成功发送');
      return true;
    } catch (e) {
      debugPrint('[Apple Store Extension] 购买失败: $e');
      return false;
    }
  }

  /// 打开促销代码兑换界面（iOS 14+）
  Future<bool> presentCodeRedemptionSheet() async {
    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await addition.presentCodeRedemptionSheet();
      debugPrint('[Apple Store Extension] 促销代码兑换界面已打开');
      return true;
    } catch (e) {
      debugPrint('[Apple Store Extension] 打开促销代码兑换界面失败: $e');
      return false;
    }
  }

  /// 构建 Apple 商品详情
  AppleProductInfo? _buildAppleProductInfo(ProductDetails details) {
    AppleProductType productType = AppleProductType.unknown;
    AppleSubscriptionInfo? subscriptionInfo;

    if (details is AppStoreProduct2Details) {
      final sk2Product = details.sk2Product;
      productType = _mapProductType(sk2Product.type);
      subscriptionInfo = _mapSubscriptionInfo(sk2Product.subscription);
    }

    return AppleProductInfo(
      productId: details.id,
      title: details.title,
      description: details.description,
      displayPrice: details.price,
      rawPrice: details.rawPrice,
      currencyCode: details.currencyCode,
      currencySymbol: details.currencySymbol,
      productType: productType,
      subscriptionInfo: subscriptionInfo,
    );
  }

  AppleSubscriptionInfo? _mapSubscriptionInfo(SK2SubscriptionInfo? info) {
    if (info == null) return null;

    return AppleSubscriptionInfo(
      subscriptionGroupId: info.subscriptionGroupID,
      subscriptionPeriod: _mapSubscriptionPeriod(info.subscriptionPeriod),
      promotionalOffers: info.promotionalOffers
          .map(_mapSubscriptionOffer)
          .toList(),
    );
  }

  AppleSubscriptionOfferInfo _mapSubscriptionOffer(SK2SubscriptionOffer offer) {
    return AppleSubscriptionOfferInfo(
      id: offer.id,
      price: offer.price,
      type: _mapOfferType(offer.type),
      period: _mapSubscriptionPeriod(offer.period),
      periodCount: offer.periodCount,
      paymentMode: _mapPaymentMode(offer.paymentMode),
    );
  }

  AppleSubscriptionPeriodInfo _mapSubscriptionPeriod(
    SK2SubscriptionPeriod period,
  ) {
    return AppleSubscriptionPeriodInfo(
      value: period.value,
      unit: _mapPeriodUnit(period.unit),
    );
  }

  AppleProductType _mapProductType(SK2ProductType type) {
    switch (type) {
      case SK2ProductType.consumable:
        return AppleProductType.consumable;
      case SK2ProductType.nonConsumable:
        return AppleProductType.nonConsumable;
      case SK2ProductType.nonRenewable:
        return AppleProductType.nonRenewable;
      case SK2ProductType.autoRenewable:
        return AppleProductType.autoRenewable;
    }
  }

  AppleSubscriptionOfferType _mapOfferType(SK2SubscriptionOfferType type) {
    switch (type) {
      case SK2SubscriptionOfferType.introductory:
        return AppleSubscriptionOfferType.introductory;
      case SK2SubscriptionOfferType.promotional:
        return AppleSubscriptionOfferType.promotional;
      case SK2SubscriptionOfferType.winBack:
        return AppleSubscriptionOfferType.winBack;
    }
  }

  AppleSubscriptionOfferPaymentMode _mapPaymentMode(
    SK2SubscriptionOfferPaymentMode mode,
  ) {
    switch (mode) {
      case SK2SubscriptionOfferPaymentMode.payAsYouGo:
        return AppleSubscriptionOfferPaymentMode.payAsYouGo;
      case SK2SubscriptionOfferPaymentMode.payUpFront:
        return AppleSubscriptionOfferPaymentMode.payUpFront;
      case SK2SubscriptionOfferPaymentMode.freeTrial:
        return AppleSubscriptionOfferPaymentMode.freeTrial;
    }
  }

  AppleSubscriptionPeriodUnit _mapPeriodUnit(SK2SubscriptionPeriodUnit unit) {
    switch (unit) {
      case SK2SubscriptionPeriodUnit.day:
        return AppleSubscriptionPeriodUnit.day;
      case SK2SubscriptionPeriodUnit.week:
        return AppleSubscriptionPeriodUnit.week;
      case SK2SubscriptionPeriodUnit.month:
        return AppleSubscriptionPeriodUnit.month;
      case SK2SubscriptionPeriodUnit.year:
        return AppleSubscriptionPeriodUnit.year;
    }
  }
}
