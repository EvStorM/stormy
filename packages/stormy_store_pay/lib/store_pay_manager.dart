import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'stormy_store_pay.dart';

export 'src/store_pay_config.dart';

/// 内购管理器 - 统一入口
///
/// 支持 Google Play 和 Apple App Store 双平台内购
///
/// 功能特性：
/// - 自动根据平台选择对应的实现（Google Play / Apple App Store）
/// - 统一的接口和回调机制
/// - 平台特定功能通过扩展类提供
/// - 购买状态管理和事件流
///
/// 基础使用（推荐）：
/// ```dart
/// // 链式初始化（推荐）
/// await StorePayManager.instance.initialize(
///   verifier: (details) async {
///     // 验证购买逻辑
///     return true;
///   },
/// );
///
/// // 设置回调
/// StorePayManager.instance.setCallbacks(
///   onPurchaseSuccess: (event) => print('购买成功: ${event.productId}'),
///   onPurchaseError: (error) => debugPrint('购买失败: ${error.message}'),
/// );
///
/// // 查询产品并购买
/// final products = await StorePayManager.instance.queryProducts(['product_id']);
/// await StorePayManager.instance.purchaseProduct(products.first);
/// ```
///
/// 平台特定功能：
/// ```dart
/// // Google Play 订阅基础计划
/// final googleExt = StorePayManager.instance.googleExtension;
/// if (googleExt != null) {
///   final basePlans = await googleExt.queryBasePlans(['subscription_id']);
///   await googleExt.purchaseWithOffer(product, offerToken: basePlans.first.offerToken);
/// }
///
/// // Apple Store 多数量购买
/// final appleExt = StorePayManager.instance.appleExtension;
/// if (appleExt != null) {
///   await appleExt.purchaseWithQuantity(product, quantity: 2);
/// }
/// ```
///
class StorePayManager {
  // ========== 单例实现 ==========
  static final StorePayManager _instance = StorePayManager._internal();

  /// 获取单例实例
  static StorePayManager get instance => _instance;

  /// 私有构造函数
  StorePayManager._internal();

  // ========== 平台策略 ==========
  StorePayManagerBase? _platformManager;
  GoogleStoreExtension? _googleExtension;
  AppleStoreExtension? _appleExtension;
  PurchaseVerifier? _purchaseVerifier;
  StorePayConfig _config = StorePayConfig.defaultConfig;

  /// 当前平台类型
  IAPPlatform get currentPlatform {
    if (Platform.isAndroid) return IAPPlatform.google;
    if (Platform.isIOS) return IAPPlatform.apple;
    return IAPPlatform.unsupported;
  }

  // ========== 平台扩展访问器 ==========

  /// 获取 Google Play 平台扩展
  ///
  /// 仅在 Android 平台可用，其他平台返回 null
  GoogleStoreExtension? get googleExtension => _googleExtension;

  /// 获取 Apple Store 平台扩展
  ///
  /// 仅在 iOS 平台可用，其他平台返回 null
  AppleStoreExtension? get appleExtension => _appleExtension;

  /// 当前购买验证器
  PurchaseVerifier? get purchaseVerifier => _purchaseVerifier;

  /// 当前配置
  StorePayConfig get config => _config;

  // ========== 状态访问器（委托给平台实现） ==========

  ValueListenable<IAPStatus> get statusNotifier =>
      _platformManager?.statusNotifier ??
      ValueNotifier(IAPStatus.uninitialized);

  IAPStatus get status => _platformManager?.status ?? IAPStatus.uninitialized;
  bool get isInitialized => _platformManager?.isInitialized ?? false;
  bool get isAvailable => _platformManager?.isAvailable ?? false;

  ValueListenable<bool> get isLoadingNotifier =>
      _platformManager?.isLoadingNotifier ?? ValueNotifier(false);

  bool get isLoading => _platformManager?.isLoading ?? false;
  List<ProductDetails> get products => _platformManager?.products ?? [];

  List<PurchaseDetails> get purchasedProducts =>
      _platformManager?.purchasedProducts ?? [];

  String? get errorMessage => _platformManager?.errorMessage;

  // ========== 事件流访问器 ==========

  Stream<IAPPurchaseEvent> get purchaseSuccessStream =>
      _platformManager?.purchaseSuccessStream ?? const Stream.empty();

  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream =>
      _platformManager?.purchaseErrorStream ?? const Stream.empty();

  Stream<List<ProductDetails>> get productsLoadedStream =>
      _platformManager?.productsLoadedStream ?? const Stream.empty();

  Stream<IAPPurchaseEvent> get purchaseRestoredStream =>
      _platformManager?.purchaseRestoredStream ?? const Stream.empty();

  // ========== 核心方法 ==========

  /// 初始化内购管理器
  ///
  /// [config] 内购配置（可选，包含自动完成购买、沙盒环境等设置）
  /// [verifier] 购买验证器（可选，如果已通过 setPurchaseVerifier 设置则无需传入）
  ///
  /// 根据当前平台自动创建对应的平台实现
  ///
  /// 返回值：初始化是否成功
  ///
  /// 注意：
  /// - 支持链式初始化：`await StorePayManager.instance.initialize(verifier: verifier)`
  /// - 重复调用会被忽略，只会初始化一次
  /// - 如果初始化失败，可以重新调用尝试初始化
  Future<bool> initialize({
    StorePayConfig? config,
    PurchaseVerifier? verifier,
  }) async {
    if (config != null) {
      _config = config;
    }

    if (verifier != null) {
      setPurchaseVerifier(verifier);
    }

    if (_purchaseVerifier == null) {
      debugPrint('[StorePayManager] 初始化前必须设置购买验证器');
      return false;
    }

    if (_platformManager != null && _platformManager!.isInitialized) {
      debugPrint('[StorePayManager] 已经初始化，跳过重复初始化');
      return true;
    }

    return _initializePlatform();
  }

  Future<bool> _initializePlatform() async {
    if (Platform.isAndroid) {
      return await _initializeGooglePlay();
    } else if (Platform.isIOS) {
      return await _initializeAppleStore();
    } else {
      debugPrint('[StorePayManager] 不支持的平台');
      return false;
    }
  }

  Future<bool> _initializeGooglePlay() async {
    debugPrint('[StorePayManager] 初始化 Google Play 平台');
    final googleManager = GoogleStoreManager();
    googleManager.setPurchaseVerifier(_purchaseVerifier);
    _platformManager = googleManager;
    final success = await googleManager.initialize();

    if (success) {
      _googleExtension = GoogleStoreExtension();
      _appleExtension = null;
    } else {
      _platformManager = null;
      _googleExtension = null;
    }

    return success;
  }

  Future<bool> _initializeAppleStore() async {
    debugPrint('[StorePayManager] 初始化 Apple Store 平台');
    final appleManager = AppleStoreManager();
    appleManager.setPurchaseVerifier(_purchaseVerifier);
    _platformManager = appleManager;
    final success = await appleManager.initialize();

    if (success) {
      _appleExtension = AppleStoreExtension();
      _googleExtension = null;
    } else {
      _platformManager = null;
      _appleExtension = null;
    }

    return success;
  }

  /// 查询产品信息
  ///
  /// [productIds] 产品ID列表
  ///
  /// 返回值：查询到的产品列表
  ///
  /// 注意：
  /// - 查询前会自动检查初始化状态
  /// - 查询结果会缓存到 products 属性中
  /// - 查询完成后会触发 productsLoadedStream 事件和 onProductsLoaded 回调
  Future<List<ProductDetails>> queryProducts(List<String> productIds) async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 内购管理器未初始化，请先调用 initialize()');
      return [];
    }

    return await _platformManager!.queryProducts(productIds);
  }

  /// 查询 Google Play 订阅基础计划
  ///
  /// 仅在 Android 平台有效，其他平台返回空列表
  ///
  /// [productIds] 订阅产品的ID列表
  Future<List<SubscriptionOfferInfo>> queryBasePlans(
    List<String> productIds,
  ) async {
    if (_googleExtension == null) {
      return [];
    }
    return await _googleExtension!.queryBasePlans(productIds);
  }

  /// 购买产品
  ///
  /// [productDetails] 要购买的产品详情
  /// [applicationUserName] 应用自定义用户标识（可选）
  ///
  /// 返回值：购买请求是否成功发起
  ///
  /// 注意：
  /// - 返回 true 只表示购买请求成功发起，不代表购买完成
  /// - 购买结果通过 purchaseSuccessStream/onPurchaseSuccess 或 purchaseErrorStream/onPurchaseError 获取
  Future<bool> purchaseProduct(
    ProductDetails productDetails, {
    String? applicationUserName,
  }) async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 内购管理器未初始化，请先调用 initialize()');
      return false;
    }

    final username = applicationUserName ?? _config.applicationUserName;
    return await _platformManager!.purchaseProduct(
      productDetails,
      applicationUserName: username,
    );
  }

  /// 恢复购买
  ///
  /// 用于恢复用户之前购买过的非消耗型产品或订阅
  ///
  /// 注意：
  /// - 恢复结果通过 purchaseRestoredStream/onPurchaseRestored 获取
  /// - iOS 平台必须提供恢复购买功能
  Future<bool> restorePurchases() async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 内购管理器未初始化，请先调用 initialize()');
      return false;
    }

    return await _platformManager!.restorePurchases();
  }

  // ========== 辅助方法 ==========

  ProductDetails? getProduct(String productId) {
    return _platformManager?.getProduct(productId);
  }

  bool hasPurchased(String productId) {
    return _platformManager?.hasPurchased(productId) ?? false;
  }

  void setCallbacks({
    OnPurchaseSuccess? onPurchaseSuccess,
    OnPurchaseError? onPurchaseError,
    OnProductsLoaded? onProductsLoaded,
    OnPurchaseRestored? onPurchaseRestored,
  }) {
    _platformManager?.setCallbacks(
      onPurchaseSuccess: onPurchaseSuccess,
      onPurchaseError: onPurchaseError,
      onProductsLoaded: onProductsLoaded,
      onPurchaseRestored: onPurchaseRestored,
    );
  }

  void setPurchaseVerifier(PurchaseVerifier? verifier) {
    _purchaseVerifier = verifier;
    _platformManager?.setPurchaseVerifier(verifier);
  }

  void dispose() {
    _platformManager?.dispose();
    _platformManager = null;
    _googleExtension = null;
    _appleExtension = null;

    debugPrint('[StorePayManager] 已清理资源');
  }
}
