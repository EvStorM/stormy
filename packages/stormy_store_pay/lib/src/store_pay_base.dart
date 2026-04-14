import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'store_pay_config.dart';
import 'store_pay_types.dart';

/// 平台扩展接口
abstract class IAPPlatformExtension {
  /// 当前支持的平台类型
  IAPPlatform get platform;

  /// 该扩展在当前环境是否可用
  bool get isAvailable;
}

/// 内购平台基础接口
abstract class StorePayManagerBase {
  // ========== 状态 =============
  ValueListenable<IAPStatus> get statusNotifier;
  IAPStatus get status;
  bool get isInitialized;
  bool get isAvailable;

  ValueListenable<bool> get isLoadingNotifier;
  bool get isLoading;

  /// 已加载的统一格式商品列表
  List<StoreProductInfo> get products;

  List<PurchaseDetails> get purchasedProducts;
  String? get errorMessage;

  // ========== 流通知 =============
  Stream<IAPPurchaseEvent> get purchaseSuccessStream;
  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream;
  Stream<List<StoreProductInfo>> get productsLoadedStream;
  Stream<IAPPurchaseEvent> get purchaseRestoredStream;

  // ========== 可选回调 =============
  OnPurchaseSuccess? onPurchaseSuccess;
  OnPurchaseError? onPurchaseError;
  OnProductsLoaded? onProductsLoaded;
  OnPurchaseRestored? onPurchaseRestored;

  // ========== 核心操作 =============
  Future<bool> initialize();

  /// 批量查询商品，并返回统一的商品结构列表
  /// [autoRestorePurchases] 如果为 true，则在查询时自动调用恢复购买，用于同步已购买信息
  Future<List<StoreProductInfo>> queryProducts(
    List<String> productIds, {
    bool autoRestorePurchases = false,
  });

  /// 购买指定商品
  /// [offer] (可选) 如果传入，代表使用某种特定优惠方案购买
  Future<bool> purchaseProduct(
    StoreProductInfo productInfo, {
    StoreOfferInfo? offer,
    String? applicationUserName,
  });

  Future<bool> restorePurchases();

  // ========== 辅助 =============

  /// 根据唯一 ID 获取统一商品详情（对于 Google 订阅，ID 是 `$productId:$basePlanId`）
  StoreProductInfo? getProduct(String unifiedId);

  bool hasPurchased(String nativeProductId);

  void setCallbacks({
    OnPurchaseSuccess? onPurchaseSuccess,
    OnPurchaseError? onPurchaseError,
    OnProductsLoaded? onProductsLoaded,
    OnPurchaseRestored? onPurchaseRestored,
  });

  void setPurchaseVerifier(PurchaseVerifier? verifier);
  void setConfig(StorePayConfig config);

  void dispose();
}
