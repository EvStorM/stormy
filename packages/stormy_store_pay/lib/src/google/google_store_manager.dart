import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../store_pay_base.dart';
import '../store_pay_config.dart';
import '../store_pay_types.dart';
import '../utils/store_product_mapper.dart';

/// Google Play 内购管理器实现
class GoogleStoreManager implements StorePayManagerBase {
  final InAppPurchase _inAppPurchase;
  bool _disposed = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ========== 配置 ==========
  StorePayConfig _config = StorePayConfig.defaultConfig;
  late final StoreProductMapper _mapper;
  final Set<String> _consumableIds = {};

  GoogleStoreManager({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
    _mapper = StoreProductMapper(isConsumable: _isConsumableProductById);
  }

  // ========== 状态管理 ==========
  final ValueNotifier<IAPStatus> _statusNotifier = ValueNotifier(
    IAPStatus.uninitialized,
  );
  bool _isAvailable = false;
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);

  // 缓存统一格式的商品。对于 Android，键是 `${productId}:${basePlanId}`，普通应用内商品是 `${productId}`
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
    if (_disposed) throw StateError("Store manager disposed");
    _config = config;
    _consumableIds.addAll(config.consumableProductIds);
  }

  void registerConsumableIds(Set<String> consumableIds) {
    _consumableIds.addAll(consumableIds);
  }

  // ========== 核心方法 ==========
  Future<bool>? _initialization;

  @override
  Future<bool> initialize() {
    if (_disposed) throw StateError('内购平台实例已销毁');
    if (isInitialized) return Future.value(true);
    return _initialization ??= _initializeOnce().whenComplete(
      () => _initialization = null,
    );
  }

  Future<bool> _initializeOnce() async {
    _statusNotifier.value = IAPStatus.initializing;
    try {
      if (_purchaseVerifier == null) {
        _setError('Google Play 内购初始化前必须先注入购买验证器', IAPStatus.initializeFailed);
        return false;
      }

      _isAvailable = await _inAppPurchase.isAvailable();
      if (_disposed) return false;

      if (!_isAvailable) {
        _setError('Google Play 内购服务不可用', IAPStatus.initializeFailed);
        return false;
      }

      _subscription = _inAppPurchase.purchaseStream.listen(
        (updates) {
          unawaited(
            _handlePurchaseUpdates(updates).catchError((
              Object error,
              StackTrace stack,
            ) {
              _notifyPurchaseError(_buildErrorEvent('处理购买事件失败', cause: error));
            }),
          );
        },
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
  Future<List<StoreProductInfo>> queryProducts(
    List<String> productIds, {
    bool autoRestorePurchases = false,
  }) async {
    if (!_checkInitialized()) return [];

    if (autoRestorePurchases) {
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

      if (_disposed) return [];
      if (response.error != null) {
        _notifyPurchaseError(_buildErrorEvent(response.error!.message));
        return [];
      }

      final unifiedProducts = _mapper.mapProducts(response.productDetails);
      cacheProducts(unifiedProducts, notifyListeners: true);

      debugPrint(
        '[Google Play] 查询到 ${response.productDetails.length} 个基础产品模型，扁平化展开后共 ${unifiedProducts.length} 个展平项',
      );
      return unifiedProducts;
    } catch (e) {
      _notifyPurchaseError(_buildErrorEvent('查询产品失败: $e'));
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
      final isConsumable = productInfo.type == StoreProductType.consumable;
      final token = offer?.id ?? productInfo.googleDefaultOfferToken;

      final purchaseParam = GooglePlayPurchaseParam(
        productDetails: productInfo.rawDetails,
        applicationUserName: applicationUserName,
        offerToken: token,
      );

      debugPrint(
        '[Google Play] 购买${isConsumable ? "消耗型" : "非消耗型/订阅"}产品: ${productInfo.id}, Token: $token',
      );

      final result = isConsumable
          ? await _inAppPurchase.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: false,
            )
          : await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!result) {
        _notifyPurchaseError(
          _buildErrorEvent('购买请求失败', productId: productInfo.nativeProductId),
        );
        return false;
      }

      debugPrint('[Google Play] 购买请求已成功发送');
      return true;
    } catch (e) {
      _notifyPurchaseError(
        _buildErrorEvent(
          '购买失败: $e',
          productId: productInfo.nativeProductId,
          cause: e,
        ),
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
        debugPrint('[Google Play] 恢复购买请求已发送');
        return true;
      } catch (e) {
        _notifyPurchaseError(_buildErrorEvent('恢复购买失败: $e', cause: e));
        return false;
      }
    });
  }

  void cacheProducts(
    List<StoreProductInfo> products, {
    bool notifyListeners = false,
  }) {
    if (_disposed) throw StateError("Store manager disposed");
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
    if (_disposed) throw StateError("Store manager disposed");
    return _productCache[unifiedId];
  }

  @override
  bool hasPurchased(String nativeProductId) {
    if (_disposed) throw StateError("Store manager disposed");
    return _purchases.any(
      (purchase) =>
          purchase.productID == nativeProductId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored),
    );
  }

  @override
  void setPurchaseVerifier(PurchaseVerifier? verifier) {
    if (_disposed) throw StateError("Store manager disposed");
    _purchaseVerifier = verifier;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _subscription?.cancel();
    _statusNotifier.dispose();
    _isLoadingNotifier.dispose();
    _purchaseSuccessController.close();
    _purchaseErrorController.close();
    _productsLoadedController.close();
    _purchaseRestoredController.close();
    _productCache.clear();
    _consumableIds.clear();
    _purchases.clear();

    debugPrint('[Google Play] 内购管理器已清理资源');
  }

  // ========== 内部通知方法 ==========
  void _notifyPurchaseEvent(IAPPurchaseEvent event) {
    if (_disposed) return;
    _purchaseSuccessController.add(event);

    if (event.isRestored) {
      _purchaseRestoredController.add(event);
    }
  }

  void _notifyPurchaseError(IAPPurchaseErrorEvent errorEvent) {
    if (_disposed) return;
    _purchaseErrorController.add(errorEvent);
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

  void _notifyProductsLoaded(List<StoreProductInfo> products) {
    if (_disposed) return;
    _productsLoadedController.add(products);
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
    if (_disposed) throw StateError('内购平台实例已销毁');
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

  bool _isConsumableProductById(String productId) {
    return _consumableIds.contains(productId);
  }

  bool _isConsumablePurchase(PurchaseDetails details) {
    return _isConsumableProductById(details.productID);
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (_disposed) return;
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[Google Play] 购买进行中: ${purchaseDetails.productID}');
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
        debugPrint('[Google Play] 购买已取消: ${purchaseDetails.productID}');
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

        if (_disposed) return;
        if (verified) {
          await _handleSuccessfulPurchase(
            purchaseDetails,
            purchaseDetails.status == PurchaseStatus.purchased
                ? IAPPurchaseLifecycle.purchased
                : IAPPurchaseLifecycle.restored,
          );

          if (!_disposed &&
              _config.autoCompletePurchases &&
              purchaseDetails.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
        } else {
          _notifyPurchaseError(
            _buildErrorEvent('购买验证失败, 订单保留以待重试', details: purchaseDetails),
          );
          // 验证失败，千万不调用 completePurchase 以便能够重启时恢复订单！
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
    IAPPurchaseLifecycle lifecycle,
  ) async {
    try {
      _upsertPurchase(purchaseDetails);
      final isConsumable = _isConsumablePurchase(purchaseDetails);

      if (isConsumable) {
        await _handleConsumablePurchase(purchaseDetails);
      }

      debugPrint(
        '[Google Play] 购买成功与验证完成: ${purchaseDetails.productID}, lifecycle: $lifecycle',
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
    debugPrint('[Google Play] 消耗型产品自动调用消耗: ${purchaseDetails.productID}');
    try {
      final androidAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await androidAddition.consumePurchase(purchaseDetails);
      debugPrint('[Google Play] 产品已在商店底层标记消耗: ${purchaseDetails.productID}');
    } catch (e) {
      debugPrint('[Google Play] 消耗产品失败: $e');
    }
  }

  Future<bool> _runPurchaseVerification(PurchaseDetails purchaseDetails) async {
    if (_purchaseVerifier == null) {
      throw StateError('购买验证器未设置，无法继续验证');
    }

    try {
      final verified = await _purchaseVerifier!(purchaseDetails);
      if (!verified) {
        debugPrint('[Google Play] 验证未通过: ${purchaseDetails.productID}');
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

  void _setError(String message, IAPStatus status) {
    if (_disposed) return;
    _errorMessage = message;
    _statusNotifier.value = status;
    debugPrint('[Google Play] $_errorMessage');
  }

  Future<T> _runWithLoading<T>(Future<T> Function() runner) async {
    if (_disposed) throw StateError('内购平台实例已销毁');
    _isLoadingNotifier.value = true;
    try {
      return await runner();
    } finally {
      if (!_disposed) _isLoadingNotifier.value = false;
    }
  }
}
