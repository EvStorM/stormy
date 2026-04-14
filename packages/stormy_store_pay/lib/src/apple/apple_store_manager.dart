import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../store_pay_base.dart';
import '../store_pay_config.dart';
import '../store_pay_types.dart';
import '../utils/store_product_mapper.dart';

/// Apple App Store 内购管理器实现
class AppleStoreManager implements StorePayManagerBase {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ========== 配置 ==========
  StorePayConfig _config = StorePayConfig.defaultConfig;
  late final StoreProductMapper _mapper;

  AppleStoreManager() {
    _mapper = StoreProductMapper(isConsumable: _isConsumableProductById);
  }

  // ========== 状态管理 ==========
  final ValueNotifier<IAPStatus> _statusNotifier = ValueNotifier(
    IAPStatus.uninitialized,
  );
  bool _isAvailable = false;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final Map<String, StoreProductInfo> _productCache = {};
  final List<PurchaseDetails> _purchases = [];
  String? _errorMessage;

  // ========== 事件流 ==========
  final StreamController<IAPPurchaseEvent> _purchaseSuccessController =
      StreamController<IAPPurchaseEvent>.broadcast();
  final StreamController<IAPPurchaseErrorEvent> _purchaseErrorController =
      StreamController<IAPPurchaseErrorEvent>.broadcast();
  final StreamController<List<StoreProductInfo>> _productsLoadedController =
      StreamController<List<StoreProductInfo>>.broadcast();
  final StreamController<IAPPurchaseEvent> _purchaseRestoredController =
      StreamController<IAPPurchaseEvent>.broadcast();

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
  List<StoreProductInfo> get products =>
      List<StoreProductInfo>.unmodifiable(_productCache.values);

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
  Stream<List<StoreProductInfo>> get productsLoadedStream =>
      _productsLoadedController.stream;

  @override
  Stream<IAPPurchaseEvent> get purchaseRestoredStream =>
      _purchaseRestoredController.stream;

  // ========== 配置注入 ==========

  @override
  void setConfig(StorePayConfig config) {
    _config = config;
  }

  // ========== 核心方法 ==========
  Completer<bool>? _initCompleter;

  @override
  Future<bool> initialize() async {
    if (_statusNotifier.value == IAPStatus.initialized) {
      debugPrint('[Apple Store] 内购管理器已经初始化，跳过重复初始化');
      return true;
    }

    if (_initCompleter != null) {
      debugPrint('[Apple Store] 内购管理器正在初始化中，等待完成...');
      return await _initCompleter!.future;
    }

    _initCompleter = Completer<bool>();
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
      _initCompleter?.complete(true);
      _initCompleter = null;
      return true;
    } catch (e) {
      _setError('初始化失败: $e', IAPStatus.initializeFailed);
      _initCompleter?.complete(false);
      _initCompleter = null;
      return false;
    }
  }

  @override
  Future<List<StoreProductInfo>> queryProducts(
    List<String> productIds, {
    bool autoRestorePurchases = false,
  }) async {
    if (!_checkInitialized()) return [];

    if (autoRestorePurchases) {
      // 在查询商品前先获取用户的已购买凭据状态，以确保后续 product.isPurchased 等属性判断准确
      await restorePurchases();
    }

    return await _runWithLoading(() => _performQueryProducts(productIds));
  }

  Future<List<StoreProductInfo>> _performQueryProducts(
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

      final unifiedProducts = _mapper.mapProducts(response.productDetails);
      cacheProducts(unifiedProducts, notifyListeners: true);

      debugPrint('[Apple Store] 查询到 ${unifiedProducts.length} 个统一商品');
      return unifiedProducts;
    } catch (e) {
      _notifyPurchaseError(_buildErrorEvent('查询产品失败: $e', cause: e));
      return [];
    }
  }

  @override
  Future<bool> purchaseProduct(
    StoreProductInfo productInfo, {
    StoreOfferInfo? offer,
    String? applicationUserName,
  }) async {
    if (!_checkInitialized()) return false;

    try {
      final rawDetails = productInfo.rawDetails;
      final isConsumable = productInfo.type == StoreProductType.consumable;

      // 如果带有特定 offer (仅限订阅)
      if (offer != null && rawDetails is AppStoreProduct2Details) {
        final sk2Product = rawDetails.sk2Product;
        try {
          // 在原生层面找对应的 offer 对象（根据 ID）
          final nativeOffer = sk2Product.subscription?.promotionalOffers
              .firstWhere((o) => o.id == offer.id);
          if (nativeOffer != null) {
            final purchaseParam = Sk2PurchaseParam.fromOffer(
              productDetails: rawDetails,
              offer: nativeOffer,
            );
            debugPrint(
              '[Apple Store] 使用订阅优惠购买: ${productInfo.id}, 优惠: ${offer.id}',
            );
            final result = await _inAppPurchase.buyNonConsumable(
              purchaseParam: purchaseParam,
            );
            return result;
          }
        } catch (_) {
          debugPrint('[Apple Store] 未在底层找到匹配的 Offer 记录: ${offer.id}');
          // 找不到则降级回正常购买
        }
      }

      final purchaseParam = AppStorePurchaseParam(productDetails: rawDetails);

      debugPrint(
        '[Apple Store] 购买 ${isConsumable ? "消耗型" : "非消耗型/订阅"}商品: ${productInfo.id}',
      );

      final result = isConsumable
          ? await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: true,
            )
          : await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!result) {
        _notifyPurchaseError(
          _buildErrorEvent('购买请求失败', productId: productInfo.id),
        );
        return false;
      }

      debugPrint('[Apple Store] 购买请求已成功发送');
      return true;
    } catch (e) {
      _notifyPurchaseError(
        _buildErrorEvent('购买失败: $e', productId: productInfo.id, cause: e),
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

  /// 缓存商品，便于后续根据 ID 提取
  void cacheProducts(
    List<StoreProductInfo> products, {
    bool notifyListeners = false,
  }) {
    if (products.isEmpty) return;

    for (final product in products) {
      _productCache[product.id] = product;
    }

    if (notifyListeners) {
      _notifyProductsLoaded(products);
    }
  }

  @override
  StoreProductInfo? getProduct(String unifiedId) {
    return _productCache[unifiedId];
  }

  @override
  bool hasPurchased(String nativeProductId) {
    return _purchases.any(
      (purchase) =>
          purchase.productID == nativeProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored),
    );
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
    _productCache.clear();
    _purchases.clear();

    debugPrint('[Apple Store] 内购管理器已清理资源');
  }

  // ========== 内部通知方法 ==========
  void _notifyPurchaseEvent(IAPPurchaseEvent event) {
    _purchaseSuccessController.add(event);

    if (event.isRestored) {
      _purchaseRestoredController.add(event);
    }
  }

  void _notifyPurchaseError(IAPPurchaseErrorEvent errorEvent) {
    _purchaseErrorController.add(errorEvent);
  }

  void _notifyProductsLoaded(List<StoreProductInfo> products) {
    _productsLoadedController.add(products);
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

  bool _isConsumableProductById(String productId) {
    return _config.consumableProductIds.contains(productId);
  }

  bool _isConsumablePurchase(
    PurchaseDetails details,
    StoreProductInfo? cached,
  ) {
    if (cached != null) {
      return cached.type == StoreProductType.consumable;
    }
    return _isConsumableProductById(details.productID);
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[Apple Store] 购买进行中: ${purchaseDetails.productID}');
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        _handlePurchaseError(purchaseDetails);
        if (_config.autoCompletePurchases &&
            purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('[Apple Store] 购买已取消: ${purchaseDetails.productID}');
        _notifyPurchaseError(
          _buildErrorEvent(
            '用户取消了购买',
            details: purchaseDetails,
            status: PurchaseStatus.canceled,
          ),
        );
        if (_config.autoCompletePurchases &&
            purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        bool verified = false;
        try {
          verified = await _runPurchaseVerification(purchaseDetails);
        } catch (e) {
          verified = false;
        }

        if (verified) {
          await _handleCompletedPurchase(
            purchaseDetails,
            purchaseDetails.status == PurchaseStatus.purchased
                ? IAPPurchaseLifecycle.purchased
                : IAPPurchaseLifecycle.restored,
          );

          if (_config.autoCompletePurchases &&
              purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        } else {
          _notifyPurchaseError(
            _buildErrorEvent('购买验证失败, 订单保留以待重试', details: purchaseDetails),
          );
          // 这里千万不调用 completePurchase，以便下一次打开 App 可以重新取到它继续验单！
        }
      }
    }
  }

  Future<void> _handleCompletedPurchase(
    PurchaseDetails purchaseDetails,
    IAPPurchaseLifecycle lifecycle,
  ) async {
    try {
      _upsertPurchase(purchaseDetails);
      final cachedProduct = _productCache.values
          .where((p) => p.nativeProductId == purchaseDetails.productID)
          .firstOrNull;
      final isConsumable = _isConsumablePurchase(
        purchaseDetails,
        cachedProduct,
      );

      // iOS 自动消耗

      final event = _createPurchaseEvent(
        purchaseDetails,
        lifecycle,
        isConsumable,
      );

      debugPrint(
        '[Apple Store] 购买成功与验证完成: ${purchaseDetails.productID}, lifecycle: $lifecycle',
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
