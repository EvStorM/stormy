import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'store_pay_types.dart';

/// 内购管理器抽象基类
///
/// 定义所有平台实现必须提供的核心功能
abstract class StorePayManagerBase {
  // ========== 状态管理 ==========

  ValueListenable<IAPStatus> get statusNotifier;
  IAPStatus get status;
  bool get isInitialized;
  bool get isAvailable;
  ValueListenable<bool> get isLoadingNotifier;
  bool get isLoading;
  List<ProductDetails> get products;
  List<PurchaseDetails> get purchasedProducts;
  String? get errorMessage;

  // ========== 事件流 ==========

  Stream<IAPPurchaseEvent> get purchaseSuccessStream;
  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream;
  Stream<List<ProductDetails>> get productsLoadedStream;
  Stream<IAPPurchaseEvent> get purchaseRestoredStream;

  // ========== 回调函数 ==========

  OnPurchaseSuccess? get onPurchaseSuccess;
  set onPurchaseSuccess(OnPurchaseSuccess? callback);

  OnPurchaseError? get onPurchaseError;
  set onPurchaseError(OnPurchaseError? callback);

  OnProductsLoaded? get onProductsLoaded;
  set onProductsLoaded(OnProductsLoaded? callback);

  OnPurchaseRestored? get onPurchaseRestored;
  set onPurchaseRestored(OnPurchaseRestored? callback);

  void setPurchaseVerifier(PurchaseVerifier? verifier);

  // ========== 核心方法 ==========

  Future<bool> initialize();

  Future<List<ProductDetails>> queryProducts(List<String> productIds);

  Future<bool> purchaseProduct(
    ProductDetails productDetails, {
    String? applicationUserName,
  });

  Future<bool> restorePurchases();

  // ========== 辅助方法 ==========

  ProductDetails? getProduct(String productId);
  bool hasPurchased(String productId);

  void setCallbacks({
    OnPurchaseSuccess? onPurchaseSuccess,
    OnPurchaseError? onPurchaseError,
    OnProductsLoaded? onProductsLoaded,
    OnPurchaseRestored? onPurchaseRestored,
  });

  void dispose();
}

/// 平台特定扩展接口
abstract class IAPPlatformExtension {
  IAPPlatform get platform;
  bool get isAvailable;
}
