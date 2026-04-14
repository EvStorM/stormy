import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'stormy_store_pay.dart';

/// 内购管理器 - 统一入口
///
/// 支持 Google Play 和 Apple App Store 双平台内购
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

  // ========== 配置 ==========

  /// 当前平台类型
  IAPPlatform get currentPlatform {
    if (Platform.isAndroid) return IAPPlatform.google;
    if (Platform.isIOS) return IAPPlatform.apple;
    return IAPPlatform.unsupported;
  }

  // ========== 平台扩展访问器 ==========

  /// 获取 Google Play 平台扩展
  /// 仅在 Android 平台可用，其他平台返回 null
  GoogleStoreExtension? get googleExtension => _googleExtension;

  /// 获取 Apple Store 平台扩展
  /// 仅在 iOS 平台可用，其他平台返回 null
  AppleStoreExtension? get appleExtension => _appleExtension;

  PurchaseVerifier? get purchaseVerifier => _purchaseVerifier;
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

  /// 当前已缓存的所有商品（已转换为统一格式）
  List<StoreProductInfo> get products => _platformManager?.products ?? [];

  List<PurchaseDetails> get purchasedProducts =>
      _platformManager?.purchasedProducts ?? [];

  String? get errorMessage => _platformManager?.errorMessage;

  // ========== 事件流访问器 ==========

  Stream<IAPPurchaseEvent> get purchaseSuccessStream =>
      _platformManager?.purchaseSuccessStream ?? const Stream.empty();

  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream =>
      _platformManager?.purchaseErrorStream ?? const Stream.empty();

  Stream<List<StoreProductInfo>> get productsLoadedStream =>
      _platformManager?.productsLoadedStream ?? const Stream.empty();

  Stream<IAPPurchaseEvent> get purchaseRestoredStream =>
      _platformManager?.purchaseRestoredStream ?? const Stream.empty();
  // ========== 核心方法 ==========

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
    googleManager.setConfig(_config);
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
    appleManager.setConfig(_config);
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

  /// 查询产品信息，并返回统一化的高级数据结构列表
  /// [autoRestorePurchases] 若为 true，则在查询商品的同时自动调用 restorePurchases() 同步已购买状态
  Future<List<StoreProductInfo>> queryProducts(
    List<String> productIds, {
    bool autoRestorePurchases = false,
  }) async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 未初始化，无法查询产品');
      return [];
    }
    return await _platformManager!.queryProducts(
      productIds,
      autoRestorePurchases: autoRestorePurchases,
    );
  }

  /// 发起购买。
  /// [offer] 如果你想通过试用/促销入口购买，请传入在此 `StoreProductInfo` 中获取到的 `StoreOfferInfo` 结构。
  Future<bool> purchaseProduct(
    StoreProductInfo productInfo, {
    StoreOfferInfo? offer,
    String? applicationUserName,
  }) async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 未初始化，无法购买产品');
      return false;
    }

    if (productInfo.isPurchased) {
      debugPrint(
        '[StorePayManager] 拦截重复购买：${productInfo.title} (${productInfo.nativeProductId}) 已经购买。',
      );
      return false;
    }

    return await _platformManager!.purchaseProduct(
      productInfo,
      offer: offer,
      applicationUserName: applicationUserName,
    );
  }

  /// 恢复购买（只恢复非消耗型和订阅型。消耗型因为会自动核销而无法直接恢复）
  Future<bool> restorePurchases() async {
    if (_platformManager == null) {
      debugPrint('[StorePayManager] 未初始化，无法恢复购买');
      return false;
    }
    return await _platformManager!.restorePurchases();
  }

  /// 根据统一ID获取商品
  StoreProductInfo? getProduct(String unifiedId) {
    return _platformManager?.getProduct(unifiedId);
  }

  /// 检查是否已购买过某商品
  bool hasPurchased(String nativeProductId) {
    return _platformManager?.hasPurchased(nativeProductId) ?? false;
  }

  // ========== 配置注入 ==========

  /// 监听一次特定的内购结果 (配合 purchaseProduct 使用)
  /// 如果成功，则返回 [IAPPurchaseEvent]；如果失败，则抛出异常
  Future<IAPPurchaseEvent> waitForPurchase(
    String productId, {
    Duration timeout = const Duration(minutes: 5),
  }) {
    final completer = Completer<IAPPurchaseEvent>();

    late StreamSubscription<IAPPurchaseEvent> successSub;
    late StreamSubscription<IAPPurchaseErrorEvent> errorSub;

    void cleanup() {
      successSub.cancel();
      errorSub.cancel();
    }

    successSub = purchaseSuccessStream.listen((event) {
      if (event.productId == productId && !completer.isCompleted) {
        cleanup();
        completer.complete(event);
      }
    });

    errorSub = purchaseErrorStream.listen((event) {
      if (event.productId == productId && !completer.isCompleted) {
        cleanup();
        completer.completeError(Exception(event.message));
      }
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        cleanup();
        throw TimeoutException('等待内购结果超时: $productId');
      },
    );
  }

  void setPurchaseVerifier(PurchaseVerifier verifier) {
    _purchaseVerifier = verifier;
    _platformManager?.setPurchaseVerifier(verifier);
  }

  void setConfig(StorePayConfig config) {
    _config = config;
    _platformManager?.setConfig(config);
  }

  /// 清理资源并断开流监听
  void dispose() {
    _platformManager?.dispose();
    _platformManager = null;
    _googleExtension = null;
    _appleExtension = null;
  }
}
