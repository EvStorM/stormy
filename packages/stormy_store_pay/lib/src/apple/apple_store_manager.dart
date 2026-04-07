import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../store_pay_base.dart';
import '../store_pay_types.dart';

/// Apple App Store 内购管理器实现
class AppleStoreManager implements StorePayManagerBase {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ========== 状态管理 ==========
  final ValueNotifier<IAPStatus> _statusNotifier = ValueNotifier(
    IAPStatus.uninitialized,
  );
  bool _isAvailable = false;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final Map<String, ProductDetails> _productCache = {};
  final Map<String, AppleProductType> _productTypeHints = {};
  final List<PurchaseDetails> _purchases = [];
  String? _errorMessage;

  // ========== 事件流 ==========
  final StreamController<IAPPurchaseEvent> _purchaseSuccessController =
      StreamController<IAPPurchaseEvent>.broadcast();
  final StreamController<IAPPurchaseErrorEvent> _purchaseErrorController =
      StreamController<IAPPurchaseErrorEvent>.broadcast();
  final StreamController<List<ProductDetails>> _productsLoadedController =
      StreamController<List<ProductDetails>>.broadcast();
  final StreamController<IAPPurchaseEvent> _purchaseRestoredController =
      StreamController<IAPPurchaseEvent>.broadcast();

  // ========== 回调函数 ==========
  @override
  OnPurchaseSuccess? onPurchaseSuccess;

  @override
  OnPurchaseError? onPurchaseError;

  @override
  OnProductsLoaded? onProductsLoaded;

  @override
  OnPurchaseRestored? onPurchaseRestored;

  PurchaseVerifier? _purchaseVerifier;

  // ========== 公开访问器 ==========
  @override
  ValueListenable<IAPStatus> get statusNotifier => _statusNotifier;

  @override
  IAPStatus get status => _statusNotifier.value;

  @override
  bool get isInitialized => _statusNotifier.value == IAPStatus.initialized;

  @override
  bool get isAvailable => _isAvailable;

  @override
  ValueListenable<bool> get isLoadingNotifier => _isLoadingNotifier;

  @override
  bool get isLoading => _isLoadingNotifier.value;

  @override
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_productCache.values);

  @override
  List<PurchaseDetails> get purchasedProducts => List.unmodifiable(_purchases);

  @override
  String? get errorMessage => _errorMessage;

  @override
  Stream<IAPPurchaseEvent> get purchaseSuccessStream =>
      _purchaseSuccessController.stream;

  @override
  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream =>
      _purchaseErrorController.stream;

  @override
  Stream<List<ProductDetails>> get productsLoadedStream =>
      _productsLoadedController.stream;

  @override
  Stream<IAPPurchaseEvent> get purchaseRestoredStream =>
      _purchaseRestoredController.stream;

  // ========== 核心方法 ==========
  @override
  Future<bool> initialize() async {
    if (_statusNotifier.value == IAPStatus.initialized) {
      debugPrint('[Apple Store] 内购管理器已经初始化，跳过重复初始化');
      return true;
    }

    if (_statusNotifier.value == IAPStatus.initializing) {
      debugPrint('[Apple Store] 内购管理器正在初始化中，等待完成...');
      await _waitForInitialization();
      return _statusNotifier.value == IAPStatus.initialized;
    }

    _statusNotifier.value = IAPStatus.initializing;

    try {
      if (!_validateVerifier()) return false;

      InAppPurchaseStoreKitPlatform.registerPlatform();
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        _setError('Apple Store 内购服务不可用', IAPStatus.initializeFailed);
        return false;
      }

      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          _notifyPurchaseError(
            _buildErrorEvent('购买监听错误: $error', cause: error),
          );
        },
      );

      _statusNotifier.value = IAPStatus.initialized;
      debugPrint('[Apple Store] 内购管理器初始化成功');
      return true;
    } catch (e) {
      _setError('初始化失败: $e', IAPStatus.initializeFailed);
      return false;
    }
  }

  @override
  Future<List<ProductDetails>> queryProducts(List<String> productIds) async {
    if (!_checkInitialized()) return [];

    return await _runWithLoading(() => _performQueryProducts(productIds));
  }

  Future<List<ProductDetails>> _performQueryProducts(
    List<String> productIds,
  ) async {
    try {
      final response = await _inAppPurchase.queryProductDetails(
        productIds.toSet(),
      );

      if (response.error != null) {
        _notifyPurchaseError(
          _buildErrorEvent(response.error!.message, cause: response.error),
        );
        return [];
      }

      final products = response.productDetails;
      cacheProducts(products, notifyListeners: true);
      debugPrint('[Apple Store] 查询到 ${products.length} 个产品');
      return products;
    } catch (e) {
      _notifyPurchaseError(_buildErrorEvent('查询产品失败: $e', cause: e));
      return [];
    }
  }

  @override
  Future<bool> purchaseProduct(
    ProductDetails productDetails, {
    String? applicationUserName,
  }) async {
    if (!_checkInitialized()) return false;

    try {
      final isConsumable = _isConsumableProduct(productDetails.id);
      final purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
      );

      debugPrint(
        '[Apple Store] 购买${isConsumable ? "消耗型" : "非消耗型/订阅"}产品: ${productDetails.id}',
      );

      final result = isConsumable
          ? await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: true,
            )
          : await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!result) {
        _notifyPurchaseError(
          _buildErrorEvent('购买请求失败', productId: productDetails.id),
        );
        return false;
      }

      debugPrint('[Apple Store] 购买请求已成功发送');
      return true;
    } catch (e) {
      _notifyPurchaseError(
        _buildErrorEvent('购买失败: $e', productId: productDetails.id, cause: e),
      );
      return false;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    if (!_checkInitialized()) return false;

    return await _runWithLoading(() async {
      try {
        await _inAppPurchase.restorePurchases();
        debugPrint('[Apple Store] 恢复购买请求已发送');
        return true;
      } catch (e) {
        _notifyPurchaseError(_buildErrorEvent('恢复购买失败: $e', cause: e));
        return false;
      }
    });
  }

  /// 同步外部（扩展）获取到的商品缓存
  void cacheProducts(
    List<ProductDetails> products, {
    bool reset = false,
    bool notifyListeners = false,
  }) {
    if (products.isEmpty) return;

    if (reset) {
      _productCache.clear();
      _productTypeHints.clear();
    }

    for (final product in products) {
      _productCache[product.id] = product;
      _productTypeHints[product.id] =
          _productTypeHints[product.id] ?? _inferAppleProductType(product);
    }

    if (notifyListeners) {
      _notifyProductsLoaded(products);
    }
  }

  /// 执行带统一 loading 状态的操作
  Future<T> runWithLoading<T>(Future<T> Function() runner) async {
    _isLoadingNotifier.value = true;
    try {
      return await runner();
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  @override
  ProductDetails? getProduct(String productId) {
    return _productCache[productId];
  }

  @override
  bool hasPurchased(String productId) {
    return _purchases.any(
      (purchase) =>
          purchase.productID == productId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored),
    );
  }

  @override
  void setCallbacks({
    OnPurchaseSuccess? onPurchaseSuccess,
    OnPurchaseError? onPurchaseError,
    OnProductsLoaded? onProductsLoaded,
    OnPurchaseRestored? onPurchaseRestored,
  }) {
    this.onPurchaseSuccess = onPurchaseSuccess;
    this.onPurchaseError = onPurchaseError;
    this.onProductsLoaded = onProductsLoaded;
    this.onPurchaseRestored = onPurchaseRestored;
  }

  @override
  void setPurchaseVerifier(PurchaseVerifier? verifier) {
    _purchaseVerifier = verifier;
  }

  /// 注册商品类型（用于精准区分消耗型/订阅/非消耗型）
  void registerProductTypes(Map<String, AppleProductType> productTypes) {
    _productTypeHints.addAll(productTypes);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusNotifier.dispose();
    _isLoadingNotifier.dispose();
    _purchaseSuccessController.close();
    _purchaseErrorController.close();
    _productsLoadedController.close();
    _purchaseRestoredController.close();
    _productCache.clear();
    _productTypeHints.clear();
    _purchases.clear();

    debugPrint('[Apple Store] 内购管理器已清理资源');
  }

  // ========== 内部通知方法 ==========
  void _notifyPurchaseEvent(IAPPurchaseEvent event) {
    _purchaseSuccessController.add(event);
    onPurchaseSuccess?.call(event);

    if (event.isRestored) {
      _purchaseRestoredController.add(event);
      onPurchaseRestored?.call(event);
    }
  }

  void _notifyPurchaseError(IAPPurchaseErrorEvent errorEvent) {
    _purchaseErrorController.add(errorEvent);
    onPurchaseError?.call(errorEvent);
  }

  void _notifyProductsLoaded(List<ProductDetails> products) {
    _productsLoadedController.add(products);
    onProductsLoaded?.call(products);
  }

  IAPPurchaseEvent _createPurchaseEvent(
    PurchaseDetails details,
    IAPPurchaseLifecycle lifecycle,
    bool isConsumable,
  ) {
    return IAPPurchaseEvent(
      productId: details.productID,
      transactionId: details.transactionId,
      details: details,
      lifecycle: lifecycle,
      isConsumable: isConsumable,
      occurredAt: DateTime.now(),
    );
  }

  IAPPurchaseErrorEvent _buildErrorEvent(
    String message, {
    PurchaseDetails? details,
    Object? cause,
    String? productId,
    PurchaseStatus? status,
  }) {
    return IAPPurchaseErrorEvent(
      message: message,
      productId: productId ?? details?.productID,
      details: details,
      purchaseStatus: status ?? details?.status,
      cause: cause,
    );
  }

  // ========== 内部验证方法 ==========
  bool _checkInitialized() {
    if (!isInitialized) {
      _errorMessage = '内购管理器未初始化，请先调用 initialize()';
      _notifyPurchaseError(_buildErrorEvent(_errorMessage!));
      debugPrint('[Apple Store] $_errorMessage');
      return false;
    }

    if (!_isAvailable) {
      _errorMessage = '内购服务不可用';
      _notifyPurchaseError(_buildErrorEvent(_errorMessage!));
      debugPrint('[Apple Store] $_errorMessage');
      return false;
    }

    return true;
  }

  // ========== 内部处理方法 ==========
  AppleProductType _resolveProductType(String productId) {
    final cachedType = _productTypeHints[productId];
    if (cachedType != null) {
      return cachedType;
    }

    final product = _productCache[productId];
    if (product != null) {
      final inferredType = _inferAppleProductType(product);
      _productTypeHints[productId] = inferredType;
      return inferredType;
    }

    return AppleProductType.unknown;
  }

  bool _isConsumableProduct(String productId) {
    return _resolveProductType(productId) == AppleProductType.consumable;
  }

  AppleProductType _inferAppleProductType(ProductDetails productDetails) {
    if (productDetails is AppStoreProduct2Details) {
      return _mapSk2ProductType(productDetails.sk2Product.type);
    }

    if (productDetails is AppStoreProductDetails) {
      final SKProductWrapper skProduct = productDetails.skProduct;
      final bool hasSubscription =
          skProduct.subscriptionPeriod != null ||
          skProduct.subscriptionGroupIdentifier != null;
      if (hasSubscription) {
        return AppleProductType.autoRenewable;
      }
      return AppleProductType.nonConsumable;
    }

    return AppleProductType.unknown;
  }

  AppleProductType _mapSk2ProductType(SK2ProductType type) {
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

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('[Apple Store] 购买进行中: ${purchaseDetails.productID}');
          break;

        case PurchaseStatus.purchased:
          await _handleCompletedPurchase(
            purchaseDetails,
            IAPPurchaseLifecycle.purchased,
          );
          break;
        case PurchaseStatus.restored:
          await _handleCompletedPurchase(
            purchaseDetails,
            IAPPurchaseLifecycle.restored,
          );
          break;

        case PurchaseStatus.error:
          _handlePurchaseError(purchaseDetails);
          break;

        case PurchaseStatus.canceled:
          debugPrint('[Apple Store] 购买已取消: ${purchaseDetails.productID}');
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _handleCompletedPurchase(
    PurchaseDetails purchaseDetails,
    IAPPurchaseLifecycle lifecycle,
  ) async {
    try {
      if (!await _runPurchaseVerification(purchaseDetails)) {
        _notifyPurchaseError(
          _buildErrorEvent('购买验证失败', details: purchaseDetails),
        );
        return;
      }

      _upsertPurchase(purchaseDetails);
      final isConsumable = _isConsumableProduct(purchaseDetails.productID);

      if (isConsumable) {
        await _handleConsumablePurchase(purchaseDetails);
      }

      final event = _createPurchaseEvent(
        purchaseDetails,
        lifecycle,
        isConsumable,
      );

      debugPrint(
        '[Apple Store] 购买成功: ${purchaseDetails.productID}, lifecycle: $lifecycle',
      );
      _notifyPurchaseEvent(event);
    } catch (e) {
      _notifyPurchaseError(
        _buildErrorEvent('处理购买失败: $e', details: purchaseDetails, cause: e),
      );
    }
  }

  void _upsertPurchase(PurchaseDetails purchaseDetails) {
    _purchases.removeWhere((existing) {
      if (existing.purchaseID != null && purchaseDetails.purchaseID != null) {
        return existing.purchaseID == purchaseDetails.purchaseID;
      }
      return existing.productID == purchaseDetails.productID;
    });
    _purchases.add(purchaseDetails);
  }

  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    final errorMsg = purchaseDetails.error?.message ?? '购买失败';
    _notifyPurchaseError(
      _buildErrorEvent(
        errorMsg,
        details: purchaseDetails,
        cause: purchaseDetails.error,
      ),
    );
  }

  Future<void> _handleConsumablePurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    debugPrint('[Apple Store] 消耗型产品购买处理: ${purchaseDetails.productID}');
    // iOS 平台自动消耗，无需额外处理
  }

  Future<bool> _runPurchaseVerification(PurchaseDetails purchaseDetails) async {
    if (_purchaseVerifier == null) {
      throw StateError('购买验证器未设置，无法继续验证');
    }

    try {
      final verified = await _purchaseVerifier!(purchaseDetails);
      if (!verified) {
        debugPrint('[Apple Store] 验证未通过: ${purchaseDetails.productID}');
      }
      return verified;
    } catch (e) {
      _notifyPurchaseError(
        _buildErrorEvent('购买验证异常: $e', details: purchaseDetails, cause: e),
      );
      return false;
    }
  }

  // ========== 内部辅助方法 ==========
  Future<void> _waitForInitialization() async {
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return _statusNotifier.value == IAPStatus.initializing;
    });
  }

  bool _validateVerifier() {
    if (_purchaseVerifier == null) {
      _setError('Apple Store 内购初始化前必须先注入购买验证器', IAPStatus.initializeFailed);
      return false;
    }
    return true;
  }

  void _setError(String message, IAPStatus status) {
    _errorMessage = message;
    _statusNotifier.value = status;
    debugPrint('[Apple Store] $_errorMessage');
  }

  Future<T> _runWithLoading<T>(Future<T> Function() runner) async {
    _isLoadingNotifier.value = true;
    try {
      return await runner();
    } finally {
      _isLoadingNotifier.value = false;
    }
  }
}
