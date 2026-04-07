import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../store_pay_base.dart';
import '../store_pay_types.dart';

/// Google Play 平台扩展
///
/// 提供 Google Play 特有的订阅优惠和消耗型产品管理功能
class GoogleStoreExtension implements IAPPlatformExtension {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  GoogleStoreExtension();

  @override
  IAPPlatform get platform => IAPPlatform.google;

  @override
  bool get isAvailable => Platform.isAndroid;

  /// 获取订阅优惠列表
  ///
  /// [productId] 订阅产品的ID
  ///
  /// 返回订阅优惠的详细信息列表
  Future<List<SubscriptionOfferInfo>> getSubscriptionOffers(
    String productId,
  ) async {
    return _performGetSubscriptionOffers(productId);
  }

  Future<List<SubscriptionOfferInfo>> _performGetSubscriptionOffers(
    String productId,
  ) async {
    try {
      final response = await _inAppPurchase.queryProductDetails({productId});

      if (response.error != null || response.productDetails.isEmpty) {
        return [];
      }

      final productDetails = response.productDetails.first;
      if (productDetails is! GooglePlayProductDetails) {
        return [];
      }

      final offerDetails =
          productDetails.productDetails.subscriptionOfferDetails;
      if (offerDetails == null || offerDetails.isEmpty) {
        return [];
      }

      final offers = offerDetails
          .map((offer) => SubscriptionOfferInfo.fromWrapper(offer))
          .toList();

      debugPrint('[Google Store Extension] 找到 ${offers.length} 个订阅优惠');
      return offers;
    } catch (e) {
      debugPrint('[Google Store Extension] 查询订阅优惠失败: $e');
      return [];
    }
  }

  /// 获取订阅基础计划列表（仅返回 base plan，不包括特殊优惠）
  ///
  /// [productIds] 订阅产品的ID列表
  ///
  /// 返回所有产品的订阅基础计划详细信息列表（offerId 为 null 的优惠）
  Future<List<SubscriptionOfferInfo>> queryBasePlans(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return [];

    return _performQueryBasePlans(productIds);
  }

  Future<List<SubscriptionOfferInfo>> _performQueryBasePlans(
    List<String> productIds,
  ) async {
    try {
      final response = await _inAppPurchase.queryProductDetails(
        productIds.toSet(),
      );

      if (response.error != null || response.productDetails.isEmpty) {
        return [];
      }

      final allBasePlans = <SubscriptionOfferInfo>[];

      for (final productDetails in response.productDetails) {
        if (productDetails is! GooglePlayProductDetails) continue;

        final offerDetails =
            productDetails.productDetails.subscriptionOfferDetails;
        if (offerDetails == null || offerDetails.isEmpty) continue;

        final basePlans = offerDetails
            .map((offer) => SubscriptionOfferInfo.fromWrapper(offer))
            .where((offer) => offer.isBasePlan)
            .toList();

        allBasePlans.addAll(basePlans);
      }

      debugPrint('[Google Store Extension] 共找到 ${allBasePlans.length} 个基础计划');
      return allBasePlans;
    } catch (e) {
      debugPrint('[Google Store Extension] 查询基础计划失败: $e');
      return [];
    }
  }

  /// 带优惠token的购买
  ///
  /// [productDetails] 要购买的产品详情
  /// [offerToken] 订阅优惠 token
  /// [applicationUserName] 应用自定义的用户标识（可选）
  /// [obfuscatedAccountId] 混淆的账户ID（可选）
  /// [obfuscatedProfileId] 混淆的配置文件ID（可选）
  Future<bool> purchaseWithOffer(
    ProductDetails productDetails, {
    required String offerToken,
    String? applicationUserName,
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  }) async {
    return _performPurchaseWithOffer(
      productDetails,
      offerToken: offerToken,
      applicationUserName: applicationUserName,
      obfuscatedAccountId: obfuscatedAccountId,
      obfuscatedProfileId: obfuscatedProfileId,
    );
  }

  Future<bool> _performPurchaseWithOffer(
    ProductDetails productDetails, {
    required String offerToken,
    String? applicationUserName,
    String? obfuscatedAccountId,
    String? obfuscatedProfileId,
  }) async {
    try {
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
        offerToken: offerToken,
      );

      debugPrint('[Google Store Extension] 使用订阅优惠购买: ${productDetails.id}');
      debugPrint('[Google Store Extension] 优惠 token: $offerToken');

      final result = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!result) {
        return false;
      }

      if (obfuscatedAccountId != null || obfuscatedProfileId != null) {
        debugPrint(
          '[Google Store Extension] 混淆账户ID: $obfuscatedAccountId, 配置文件ID: $obfuscatedProfileId',
        );
      }

      return true;
    } catch (e) {
      debugPrint('[Google Store Extension] 购买失败: $e');
      return false;
    }
  }

  /// 消耗产品（Android特定）
  ///
  /// [purchaseDetails] 要消耗的购买详情
  Future<bool> consumePurchase(PurchaseDetails purchaseDetails) async {
    try {
      final androidAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await androidAddition.consumePurchase(purchaseDetails);
      debugPrint('[Google Store Extension] 产品已消耗: ${purchaseDetails.productID}');
      return true;
    } catch (e) {
      debugPrint('[Google Store Extension] 消耗产品失败: $e');
      return false;
    }
  }
}
