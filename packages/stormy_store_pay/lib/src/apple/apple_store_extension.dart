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

  /// 多次购买消耗型产品（iOS特定）
  ///
  /// 注意：iOS IAP 不支持原生的「指定数量购买」，此方法通过循环发起多次购买实现。
  /// 仅适用于消耗型产品。每次购买都是独立的交易，会分别触发购买回调。
  ///
  /// [quantity] 购买次数，必须 >= 1
  Future<bool> purchaseWithQuantity(
    StoreProductInfo productInfo, {
    int quantity = 1,
    String? applicationUserName,
  }) async {
    if (quantity < 1) return false;
    if (productInfo.type != StoreProductType.consumable) return false;

    return _performPurchaseWithQuantity(
      productInfo.rawDetails,
      quantity: quantity,
      applicationUserName: applicationUserName,
    );
  }

  Future<bool> _performPurchaseWithQuantity(
    ProductDetails productDetails, {
    required int quantity,
    String? applicationUserName,
  }) async {
    try {
      final purchaseParam = AppStorePurchaseParam(
        productDetails: productDetails,
      );

      debugPrint(
        '[Apple Store Extension] 多次购买产品: ${productDetails.id}, 次数: $quantity',
      );

      for (int i = 0; i < quantity; i++) {
        final result = await _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
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

  /// 使用签名优惠购买产品 (Apple 高级用法)
  Future<bool> purchaseWithOfferSignature(
    StoreProductInfo productInfo,
    StoreOfferInfo offer,
    SK2SubscriptionOfferSignature signature, {
    String? applicationUserName,
  }) async {
    final rawDetails = productInfo.rawDetails;
    if (rawDetails is! AppStoreProduct2Details) return false;

    final nativeOffer = rawDetails.sk2Product.subscription?.promotionalOffers.firstWhere((o) => o.id == offer.id);
    if (nativeOffer == null) return false;

    try {
      final purchaseParam = Sk2PurchaseParam.fromOffer(
        productDetails: rawDetails,
        offer: nativeOffer,
        signature: signature,
      );

      debugPrint('[Apple Store Extension] 使用订阅签名优惠购买: ${productInfo.id}');

      final result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return result;
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
}
