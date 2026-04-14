import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../store_pay_base.dart';
import '../store_pay_types.dart';

/// Google Play 平台扩展
///
/// 提供 Google Play 特有的消耗型产品管理功能等
class GoogleStoreExtension implements IAPPlatformExtension {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  GoogleStoreExtension();

  @override
  IAPPlatform get platform => IAPPlatform.google;

  @override
  bool get isAvailable => Platform.isAndroid;

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
