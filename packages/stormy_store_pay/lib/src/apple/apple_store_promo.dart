import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Apple Store 促销码功能
///
/// 提供 App Store 促销码兑换相关功能
class AppleStorePromo {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  AppleStorePromo();

  /// 打开促销代码兑换界面（iOS 14+）
  ///
  /// 允许用户输入促销代码兑换内购产品
  /// 成功返回 true，失败返回 false
  Future<bool> presentCodeRedemptionSheet() async {
    try {
      final addition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await addition.presentCodeRedemptionSheet();
      debugPrint('[Apple Store Promo] 促销代码兑换界面已打开');
      return true;
    } catch (e) {
      debugPrint('[Apple Store Promo] 打开促销代码兑换界面失败: $e');
      return false;
    }
  }
}
