import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'stormy_store_pay.dart';

/// Stable facade: subscribe before initialize; dispose ends this instance.
class StorePayManager {
  static StorePayManager? _instance;
  static StorePayManager get instance =>
      _instance ??= StorePayManager.withFactory(_createPlatform);
  StorePayManager.withFactory(this._factory, {IAPPlatform Function()? platform})
    : _platform = platform ?? _currentPlatform;

  final StorePayManagerBase Function(IAPPlatform) _factory;
  final IAPPlatform Function() _platform;
  StorePayManagerBase? _platformManager;
  GoogleStoreExtension? _googleExtension;
  AppleStoreExtension? _appleExtension;
  PurchaseVerifier? _purchaseVerifier;
  StorePayConfig _config = StorePayConfig.defaultConfig;
  Future<bool>? _initialization;
  Future<void>? _disposal;
  bool _disposed = false;
  String? _errorMessage;
  final _status = ValueNotifier(IAPStatus.uninitialized);
  final _loading = ValueNotifier(false);
  final _success = StreamController<IAPPurchaseEvent>.broadcast();
  final _errors = StreamController<IAPPurchaseErrorEvent>.broadcast();
  final _products = StreamController<List<StoreProductInfo>>.broadcast();
  final _restored = StreamController<IAPPurchaseEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<_PurchaseWaiter> _waiters = {};
  final Set<String> _activeProducts = {};
  VoidCallback? _platformLoadingListener;

  static IAPPlatform _currentPlatform() {
    if (!kIsWeb && Platform.isAndroid) return IAPPlatform.google;
    if (!kIsWeb && Platform.isIOS) return IAPPlatform.apple;
    return IAPPlatform.unsupported;
  }

  static StorePayManagerBase _createPlatform(IAPPlatform platform) =>
      switch (platform) {
        IAPPlatform.google => GoogleStoreManager(),
        IAPPlatform.apple => AppleStoreManager(),
        IAPPlatform.unsupported => throw UnsupportedError('不支持的内购平台'),
      };
  void _checkActive() {
    if (_disposed) throw StateError('StorePayManager 已销毁，请获取新实例');
  }

  IAPPlatform get currentPlatform => _platform();
  GoogleStoreExtension? get googleExtension => _googleExtension;
  AppleStoreExtension? get appleExtension => _appleExtension;
  PurchaseVerifier? get purchaseVerifier => _purchaseVerifier;
  StorePayConfig get config => _config;
  ValueListenable<IAPStatus> get statusNotifier => _status;
  ValueListenable<bool> get isLoadingNotifier => _loading;
  IAPStatus get status => _status.value;
  bool get isInitialized => !_disposed && status == IAPStatus.initialized;
  bool get isAvailable =>
      !_disposed && (_platformManager?.isAvailable ?? false);
  bool get isLoading => _loading.value;
  List<StoreProductInfo> get products => _platformManager?.products ?? const [];
  List<PurchaseDetails> get purchasedProducts =>
      _platformManager?.purchasedProducts ?? const [];
  String? get errorMessage => _errorMessage ?? _platformManager?.errorMessage;
  late final Stream<IAPPurchaseEvent> purchaseSuccessStream = _success.stream;
  late final Stream<IAPPurchaseErrorEvent> purchaseErrorStream = _errors.stream;
  late final Stream<List<StoreProductInfo>> productsLoadedStream =
      _products.stream;
  late final Stream<IAPPurchaseEvent> purchaseRestoredStream = _restored.stream;

  Future<bool> initialize({
    StorePayConfig? config,
    PurchaseVerifier? verifier,
  }) {
    _checkActive();
    if (config != null) setConfig(config);
    if (verifier != null) setPurchaseVerifier(verifier);
    if (isInitialized) return Future.value(true);
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<bool> _initialize() async {
    _status.value = IAPStatus.initializing;
    _errorMessage = null;
    try {
      if (_purchaseVerifier == null) throw StateError('初始化前必须设置购买验证器');
      final manager = _factory(currentPlatform);
      _platformManager = manager;
      manager.setConfig(_config);
      manager.setPurchaseVerifier(_purchaseVerifier);
      // Forward before native initialization, which may immediately restore transactions.
      _subscriptions.addAll([
        manager.purchaseSuccessStream.listen((event) {
          if (!_disposed) _success.add(event);
        }),
        manager.purchaseErrorStream.listen((event) {
          if (!_disposed) _errors.add(event);
        }),
        manager.productsLoadedStream.listen((event) {
          if (!_disposed) _products.add(event);
        }),
        manager.purchaseRestoredStream.listen((event) {
          if (!_disposed) _restored.add(event);
        }),
      ]);
      _platformLoadingListener = () {
        if (!_disposed) _loading.value = manager.isLoading;
      };
      manager.isLoadingNotifier.addListener(_platformLoadingListener!);
      final success = await manager.initialize();
      _checkActive();
      if (!success) throw StateError(manager.errorMessage ?? '内购初始化失败');
      _status.value = IAPStatus.initialized;
      if (manager is GoogleStoreManager)
        _googleExtension = GoogleStoreExtension();
      if (manager is AppleStoreManager) _appleExtension = AppleStoreExtension();
      return true;
    } catch (error) {
      if (_disposed) rethrow;
      _errorMessage = error.toString();
      await _detachPlatform();
      if (!_disposed) _status.value = IAPStatus.initializeFailed;
      return false;
    }
  }

  Future<void> _detachPlatform() async {
    final manager = _platformManager;
    _platformManager = null;
    final listener = _platformLoadingListener;
    _platformLoadingListener = null;
    if (manager != null && listener != null)
      manager.isLoadingNotifier.removeListener(listener);
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );
    manager?.dispose();
    _googleExtension = null;
    _appleExtension = null;
  }

  Future<List<StoreProductInfo>> queryProducts(
    List<String> productIds, {
    bool autoRestorePurchases = false,
  }) async {
    _checkActive();
    return await _platformManager?.queryProducts(
          productIds,
          autoRestorePurchases: autoRestorePurchases,
        ) ??
        [];
  }

  Future<bool> purchaseProduct(
    StoreProductInfo productInfo, {
    StoreOfferInfo? offer,
    String? applicationUserName,
  }) async {
    _checkActive();
    if (productInfo.isPurchased) return false;
    return await _platformManager?.purchaseProduct(
          productInfo,
          offer: offer,
          applicationUserName: applicationUserName,
        ) ??
        false;
  }

  Future<bool> restorePurchases() async {
    _checkActive();
    return await _platformManager?.restorePurchases() ?? false;
  }

  StoreProductInfo? getProduct(String id) {
    _checkActive();
    return _platformManager?.getProduct(id);
  }

  bool hasPurchased(String id) {
    _checkActive();
    return _platformManager?.hasPurchased(id) ?? false;
  }

  _PurchaseWaiter _wait(String productId, Duration timeout) {
    _checkActive();
    if (timeout <= Duration.zero) throw ArgumentError.value(timeout, 'timeout');
    late final _PurchaseWaiter waiter;
    waiter = _PurchaseWaiter(
      productId,
      timeout,
      purchaseSuccessStream,
      purchaseErrorStream,
      () => _waiters.remove(waiter),
    );
    _waiters.add(waiter);
    return waiter;
  }

  Future<IAPPurchaseEvent> waitForPurchase(
    String productId, {
    Duration timeout = const Duration(minutes: 5),
  }) => _wait(productId, timeout).future;

  Future<IAPPurchaseEvent> purchaseAndWait(
    StoreProductInfo product, {
    StoreOfferInfo? offer,
    String? applicationUserName,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    _checkActive();
    final id = product.nativeProductId;
    if (!_activeProducts.add(id)) throw StateError('该商品已有待处理购买: $id');
    _PurchaseWaiter? waiter;
    try {
      waiter = _wait(id, timeout);
      final pending = waiter;
      final dispatch =
          purchaseProduct(
            product,
            offer: offer,
            applicationUserName: applicationUserName,
          ).then(
            (started) {
              if (!started) pending.fail(StorePayException('购买请求未发起: $id'));
            },
            onError: (Object error, StackTrace stack) {
              pending.fail(error, stack);
            },
          );
      // The waiter bounds the entire operation, including a stalled native launch.
      unawaited(dispatch);
      return await pending.future;
    } finally {
      waiter?.cleanup();
      _activeProducts.remove(id);
    }
  }

  void setPurchaseVerifier(PurchaseVerifier verifier) {
    _checkActive();
    _purchaseVerifier = verifier;
    _platformManager?.setPurchaseVerifier(verifier);
  }

  void setConfig(StorePayConfig config) {
    _checkActive();
    _config = config;
    _platformManager?.setConfig(config);
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    if (identical(_instance, this)) _instance = null;
    for (final waiter in _waiters.toList()) {
      waiter.fail(StateError('内购服务已销毁'));
    }
    await _detachPlatform();
    await Future.wait([
      _success.close(),
      _errors.close(),
      _products.close(),
      _restored.close(),
    ]);
    _status.dispose();
    _loading.dispose();
  }
}

class _PurchaseWaiter {
  _PurchaseWaiter(
    String id,
    Duration timeout,
    Stream<IAPPurchaseEvent> success,
    Stream<IAPPurchaseErrorEvent> errors,
    this.onCleanup,
  ) {
    _subscriptions.add(
      success.listen((event) {
        if (event.productId == id &&
            event.isFirstPurchase &&
            !_completer.isCompleted)
          _completer.complete(event);
      }),
    );
    _subscriptions.add(
      errors.listen((event) {
        if (event.productId == id)
          fail(
            StorePayException(
              event.message,
              status: event.purchaseStatus,
              cause: event.cause,
            ),
          );
      }),
    );
    _timer = Timer(
      timeout,
      () => fail(TimeoutException('等待内购结果超时: $id', timeout)),
    );
    future = _completer.future.whenComplete(cleanup);
  }
  final void Function() onCleanup;
  final _completer = Completer<IAPPurchaseEvent>();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _timer;
  late final Future<IAPPurchaseEvent> future;
  bool _cleaned = false;
  void fail(Object error, [StackTrace? stack]) {
    if (!_completer.isCompleted) _completer.completeError(error, stack);
  }

  void cleanup() {
    if (_cleaned) return;
    _cleaned = true;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    onCleanup();
  }
}
