import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

PurchaseDetails details() => PurchaseDetails(
  productID: 'sku',
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'receipt',
    source: 'test',
  ),
  transactionDate: '1',
  status: PurchaseStatus.purchased,
)..pendingCompletePurchase = true;
IAPPurchaseEvent event() => IAPPurchaseEvent(
  productId: 'sku',
  details: details(),
  lifecycle: IAPPurchaseLifecycle.purchased,
  isConsumable: false,
  occurredAt: DateTime.now(),
);
StoreProductInfo product() => StoreProductInfo(
  id: 'sku:base',
  nativeProductId: 'sku',
  title: 'test',
  description: 'test',
  type: StoreProductType.subscription,
  priceInfo: const StorePriceInfo(
    currentPrice: 1,
    formattedPrice: '1',
    currencyCode: 'USD',
    currencySymbol: r'$',
  ),
  rawDetails: ProductDetails(
    id: 'sku',
    title: 'test',
    description: 'test',
    price: '1',
    rawPrice: 1,
    currencyCode: 'USD',
  ),
);

class FakeManager implements StorePayManagerBase {
  final success = StreamController<IAPPurchaseEvent>.broadcast(sync: true);
  final errors = StreamController<IAPPurchaseErrorEvent>.broadcast(sync: true);
  @override
  final ValueNotifier<IAPStatus> statusNotifier = ValueNotifier(
    IAPStatus.uninitialized,
  );
  @override
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  int initCount = 0;
  bool emitOnInit = false;
  Future<bool> Function()? onPurchase;
  Completer<bool>? initialization;
  @override
  bool get isInitialized => status == IAPStatus.initialized;
  @override
  IAPStatus get status => statusNotifier.value;
  @override
  bool get isLoading => false;
  @override
  bool get isAvailable => true;
  @override
  String? get errorMessage => null;
  @override
  Stream<IAPPurchaseEvent> get purchaseSuccessStream => success.stream;
  @override
  Stream<IAPPurchaseErrorEvent> get purchaseErrorStream => errors.stream;
  @override
  Stream<IAPPurchaseEvent> get purchaseRestoredStream => const Stream.empty();
  @override
  Stream<List<StoreProductInfo>> get productsLoadedStream =>
      const Stream.empty();
  @override
  Future<bool> initialize() async {
    initCount++;
    if (emitOnInit) success.add(event());
    final result = await (initialization?.future ?? Future.value(true));
    statusNotifier.value = result
        ? IAPStatus.initialized
        : IAPStatus.initializeFailed;
    return result;
  }

  @override
  Future<bool> purchaseProduct(
    StoreProductInfo info, {
    StoreOfferInfo? offer,
    String? applicationUserName,
  }) => onPurchase?.call() ?? Future.value(true);
  @override
  void setConfig(StorePayConfig config) {}
  @override
  void setPurchaseVerifier(PurchaseVerifier? verifier) {}
  @override
  void dispose() {
    unawaited(success.close());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeIap implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = false;
  int completed = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'facade initialization failure retries with new adapter and stable streams',
    () async {
      final failed = FakeManager()..initialization = Completer<bool>();
      final ready = FakeManager()..emitOnInit = true;
      var calls = 0;
      final manager = StorePayManager.withFactory(
        (_) => calls++ == 0 ? failed : ready,
      );
      final stream = manager.purchaseSuccessStream;
      final event = stream.first;
      final first = manager.initialize(verifier: (_) async => true);
      failed.initialization!.complete(false);
      expect(await first, isFalse);
      expect(await manager.initialize(), isTrue);
      expect((await event).productId, 'sku');
      expect(manager.purchaseSuccessStream, same(stream));
      await manager.dispose();
    },
  );

  for (final apple in [false, true]) {
    test(
      '${apple ? "Apple" : "Google"} ignores verification completed after disposal',
      () async {
        final iap = FakeIap()..available = true;
        final StorePayManagerBase manager = apple
            ? AppleStoreManager(inAppPurchase: iap, registerPlatform: () {})
            : GoogleStoreManager(inAppPurchase: iap);
        final entered = Completer<void>();
        final verified = Completer<bool>();
        manager.setPurchaseVerifier((_) {
          entered.complete();
          return verified.future;
        });
        expect(await manager.initialize(), isTrue);
        final successes = <IAPPurchaseEvent>[];
        final subscription = manager.purchaseSuccessStream.listen(
          successes.add,
        );
        iap.updates.add([details()]);
        await entered.future;
        manager.dispose();
        verified.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(iap.completed, 0);
        expect(successes, isEmpty);
        await subscription.cancel();
        await iap.updates.close();
      },
    );
  }

  test(
    'subscriptions are stable before init and see initialization events',
    () async {
      final fake = FakeManager()
        ..emitOnInit = true
        ..initialization = Completer<bool>();
      final manager = StorePayManager.withFactory(
        (_) => fake,
        platform: () => IAPPlatform.google,
      );
      final stream = manager.purchaseSuccessStream;
      final notifier = manager.statusNotifier;
      final next = stream.first;
      final first = manager.initialize(verifier: (_) async => true);
      final second = manager.initialize();
      fake.initialization!.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect((await next).productId, 'sku');
      expect(fake.initCount, 1);
      expect(manager.purchaseSuccessStream, same(stream));
      expect(manager.statusNotifier, same(notifier));
      await manager.dispose();
    },
  );

  test(
    'purchaseAndWait catches fast callbacks and matches native ID',
    () async {
      final fake = FakeManager();
      final manager = StorePayManager.withFactory((_) => fake);
      await manager.initialize(verifier: (_) async => true);
      fake.onPurchase = () async {
        fake.success.add(event());
        return true;
      };
      expect((await manager.purchaseAndWait(product())).productId, 'sku');
      await manager.dispose();
    },
  );

  test(
    'same SKU concurrency, native launch stall, timeout, and disposal terminate waits',
    () async {
      final fake = FakeManager();
      final manager = StorePayManager.withFactory((_) => fake);
      await manager.initialize(verifier: (_) async => true);
      final first = manager.purchaseAndWait(product());
      final firstAssertion = expectLater(first, throwsStateError);
      await expectLater(manager.purchaseAndWait(product()), throwsStateError);
      await manager.dispose();
      await firstAssertion;
      final another = FakeManager()
        ..onPurchase = () => Completer<bool>().future;
      final next = StorePayManager.withFactory((_) => another);
      await next.initialize(verifier: (_) async => true);
      await expectLater(
        next.purchaseAndWait(
          product(),
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      another.onPurchase = () async {
        another.success.add(event());
        return true;
      };
      expect((await next.purchaseAndWait(product())).productId, 'sku');
      await next.dispose();
    },
  );

  test('launch failure and cancellation produce immediate errors', () async {
    final fake = FakeManager();
    final manager = StorePayManager.withFactory((_) => fake);
    await manager.initialize(verifier: (_) async => true);
    fake.onPurchase = () async => false;
    await expectLater(
      manager.purchaseAndWait(product()),
      throwsA(isA<StorePayException>()),
    );
    fake.onPurchase = () async {
      fake.errors.add(
        IAPPurchaseErrorEvent(
          message: 'cancelled',
          productId: 'sku',
          purchaseStatus: PurchaseStatus.canceled,
        ),
      );
      return true;
    };
    await expectLater(
      manager.purchaseAndWait(product()),
      throwsA(isA<StorePayException>()),
    );
    await manager.dispose();
  });

  for (final apple in [false, true]) {
    test(
      '${apple ? 'Apple' : 'Google'} initialization failures complete and verification failure preserves order',
      () async {
        final iap = FakeIap();
        final StorePayManagerBase manager = apple
            ? AppleStoreManager(inAppPurchase: iap, registerPlatform: () {})
            : GoogleStoreManager(inAppPurchase: iap);
        expect(await manager.initialize(), isFalse);
        manager.setPurchaseVerifier((_) async => false);
        expect(
          await manager.initialize().timeout(const Duration(seconds: 1)),
          isFalse,
        );
        iap.available = true;
        expect(
          await manager.initialize().timeout(const Duration(seconds: 1)),
          isTrue,
        );
        final success = <IAPPurchaseEvent>[];
        final sub = manager.purchaseSuccessStream.listen(success.add);
        final error = manager.purchaseErrorStream.first;
        iap.updates.add([details()]);
        await error;
        expect(success, isEmpty);
        expect(iap.completed, 0);
        manager.dispose();
        await sub.cancel();
        await iap.updates.close();
      },
    );
  }
}
