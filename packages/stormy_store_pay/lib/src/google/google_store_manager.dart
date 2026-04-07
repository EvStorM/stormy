import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../store_pay_base.dart';
import '../store_pay_types.dart';

/// Google Play 内购管理器实现
class GoogleStoreManager implements StorePayManagerBase {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ========== 状态管理 ==========
  final ValueNotifier<IAPStatus> _statusNotifier = ValueNotifier(
    IAPStatus.uninitialized,
  );
  bool _isAvailable = false;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  List<ProductDetails> _products = [];
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
  List<ProductDetails> get products => List.unmodifiable(_products);

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
      debugPrint('[Google Play] 内购管理器已经初始化，跳过重复初始化');
      return true;
    }

    if (_statusNotifier.value == IAPStatus.initializing) {
      debugPrint('[Google Play] 内购管理器正在初始化中，等待完成...');
      await _waitForInitialization();
      return _statusNotifier.value == IAPStatus.initialized;
    }

    _statusNotifier.value = IAPStatus.initializing;

    try {
      _isAvailable = await _inAppPurchase.isAvailable();

      if (!_isAvailable) {
        _setError('Google Play 内购服务不可用', IAPStatus.initializeFailed);
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
      debugPrint('[Google Play] 内购管理器初始化成功');
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
        _notifyPurchaseError(_buildErrorEvent(response.error!.message));
        return [];
      }

      _products = response.productDetails;
      _notifyProductsLoaded(_products);
      debugPrint('[Google Play] 查询到 ${_products.length} 个产品');
      return _products;
    } catch (e) {
      _notifyPurchaseError(_buildErrorEvent('查询产品失败: $e'));
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
      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
      );

      debugPrint(
        '[Google Play] 购买${isConsumable ? "消耗型" : "非消耗型/订阅"}产品: ${productDetails.id}',
      );

      final result = isConsumable
          ? await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: false,
            )
          : await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!result) {
        _notifyPurchaseError(
          _buildErrorEvent('购买请求失败', productId: productDetails.id),
        );
        return false;
      }

      debugPrint('[Google Play] 购买请求已成功发送');
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

    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('[Google Play] 恢复购买请求已发送');
      return true;
    } catch (e) {
      _notifyPurchaseError(_buildErrorEvent('恢复购买失败: $e', cause: e));
      return false;
    }
  }

  @override
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
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

  @override
  void dispose() {
    _subscription?.cancel();
    _statusNotifier.dispose();
    _isLoadingNotifier.dispose();
    _purchaseSuccessController.close();
    _purchaseErrorController.close();
    _productsLoadedController.close();
    _purchaseRestoredController.close();

    debugPrint('[Google Play] 内购管理器已清理资源');
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

  void _notifyProductsLoaded(List<ProductDetails> products) {
    _productsLoadedController.add(products);
    onProductsLoaded?.call(products);
  }

  IAPPurchaseEvent _createPurchaseEvent(
    PurchaseDetails purchaseDetails,
    IAPPurchaseLifecycle lifecycle,
    bool isConsumable,
  ) {
    return IAPPurchaseEvent(
      productId: purchaseDetails.productID,
      transactionId: purchaseDetails.transactionId,
      details: purchaseDetails,
      lifecycle: lifecycle,
      isConsumable: isConsumable,
      occurredAt: DateTime.now(),
    );
  }

  // ========== 内部验证方法 ==========
  bool _checkInitialized() {
    if (!isInitialized) {
      _errorMessage = '内购管理器未初始化，请先调用 initialize()';
      _notifyPurchaseError(_buildErrorEvent(_errorMessage!));
      debugPrint('[Google Play] $_errorMessage');
      return false;
    }

    if (!_isAvailable) {
      _errorMessage = '内购服务不可用';
      _notifyPurchaseError(_buildErrorEvent(_errorMessage!));
      debugPrint('[Google Play] $_errorMessage');
      return false;
    }

    return true;
  }

  // ========== 内部处理方法 ==========
  bool _isConsumableProduct(String productId) {
    final lowerId = productId.toLowerCase();
    return lowerId.contains('consumable') ||
        lowerId.contains('token') ||
        lowerId.contains('coin') ||
        lowerId.contains('credit');
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('[Google Play] 购买进行中: ${purchaseDetails.productID}');
          break;

        case PurchaseStatus.purchased:
          await _handleSuccessfulPurchase(
            purchaseDetails,
            IAPPurchaseLifecycle.purchased,
          );
          break;
        case PurchaseStatus.restored:
          await _handleSuccessfulPurchase(
            purchaseDetails,
            IAPPurchaseLifecycle.restored,
          );
          break;

        case PurchaseStatus.error:
          _handlePurchaseError(purchaseDetails);
          break;

        case PurchaseStatus.canceled:
          debugPrint('[Google Play] 购买已取消: ${purchaseDetails.productID}');
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
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

      debugPrint(
        '[Google Play] 购买成功: ${purchaseDetails.productID}, lifecycle: $lifecycle',
      );

      final event = _createPurchaseEvent(
        purchaseDetails,
        lifecycle,
        isConsumable,
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
    debugPrint('[Google Play] 消耗型产品购买处理: ${purchaseDetails.productID}');
    // 消耗型产品需要手动消耗，通过 GoogleStoreExtension.consumePurchase() 调用
  }

  Future<bool> _runPurchaseVerification(PurchaseDetails purchaseDetails) async {
    if (_purchaseVerifier != null) {
      return await _purchaseVerifier!(purchaseDetails);
    }

    debugPrint('[Google Play] 未设置购买验证回调，默认验证通过: ${purchaseDetails.productID}');
    return true;
  }

  // ========== 内部辅助方法 ==========
  Future<void> _waitForInitialization() async {
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return _statusNotifier.value == IAPStatus.initializing;
    });
  }

  void _setError(String message, IAPStatus status) {
    _errorMessage = message;
    _statusNotifier.value = status;
    debugPrint('[Google Play] $_errorMessage');
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
