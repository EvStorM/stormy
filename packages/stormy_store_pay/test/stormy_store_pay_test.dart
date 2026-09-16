import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

void main() {
  group('StorePayManager', () {
    test('should be a singleton', () {
      final instance1 = StorePayManager.instance;
      final instance2 = StorePayManager.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should not be initialized by default', () {
      expect(StorePayManager.instance.isInitialized, isFalse);
    });

    test('should not be available by default', () {
      expect(StorePayManager.instance.isAvailable, isFalse);
    });

    test('should have default config', () {
      expect(StorePayManager.instance.config.autoCompletePurchases, isTrue);
      expect(StorePayManager.instance.config.isForTest, isFalse);
    });

    test('should report unsupported platform on test environment', () {
      expect(
        StorePayManager.instance.currentPlatform,
        equals(IAPPlatform.unsupported),
      );
    });

    test('should return null for platform extensions before init', () {
      expect(StorePayManager.instance.googleExtension, isNull);
      expect(StorePayManager.instance.appleExtension, isNull);
    });

    test('should return empty product list before init', () {
      expect(StorePayManager.instance.products, isEmpty);
    });

    test('should return empty purchased products before init', () {
      expect(StorePayManager.instance.purchasedProducts, isEmpty);
    });

    test('initialize should return false without verifier', () async {
      final result = await StorePayManager.instance.initialize();
      expect(result, isFalse);
    });

    test('dispose should clear platform manager', () async {
      await StorePayManager.instance.dispose();
      expect(StorePayManager.instance.isInitialized, isFalse);
      expect(StorePayManager.instance.googleExtension, isNull);
      expect(StorePayManager.instance.appleExtension, isNull);
    });
  });

  group('IAPStatus', () {
    test('should have all expected values', () {
      expect(IAPStatus.values.length, equals(4));
      expect(IAPStatus.uninitialized, isNotNull);
      expect(IAPStatus.initializing, isNotNull);
      expect(IAPStatus.initialized, isNotNull);
      expect(IAPStatus.initializeFailed, isNotNull);
    });
  });

  group('IAPPlatform', () {
    test('should have all expected values', () {
      expect(IAPPlatform.values.length, equals(3));
      expect(IAPPlatform.google, isNotNull);
      expect(IAPPlatform.apple, isNotNull);
      expect(IAPPlatform.unsupported, isNotNull);
    });
  });

  group('IAPPurchaseLifecycle', () {
    test('should have all expected values', () {
      expect(IAPPurchaseLifecycle.values.length, equals(3));
      expect(IAPPurchaseLifecycle.purchased, isNotNull);
      expect(IAPPurchaseLifecycle.restored, isNotNull);
      expect(IAPPurchaseLifecycle.pending, isNotNull);
    });
  });

  group('StorePayConfig', () {
    test('should have default values', () {
      const config = StorePayConfig();
      expect(config.autoCompletePurchases, isTrue);
      expect(config.isForTest, isFalse);
      expect(config.applicationUserName, isNull);
    });

    test('should accept custom values', () {
      const config = StorePayConfig(
        autoCompletePurchases: false,
        isForTest: true,
        applicationUserName: 'user_123',
      );
      expect(config.autoCompletePurchases, isFalse);
      expect(config.isForTest, isTrue);
      expect(config.applicationUserName, equals('user_123'));
    });

    test('should provide defaultConfig constant', () {
      const defaultConfig = StorePayConfig.defaultConfig;
      expect(defaultConfig.autoCompletePurchases, isTrue);
      expect(defaultConfig.isForTest, isFalse);
    });
  });

  group('StoreProductType', () {
    test('should have all expected values', () {
      expect(StoreProductType.values.length, equals(4));
      expect(StoreProductType.consumable, isNotNull);
      expect(StoreProductType.nonConsumable, isNotNull);
      expect(StoreProductType.subscription, isNotNull);
      expect(StoreProductType.unknown, isNotNull);
    });
  });

  group('StoreOfferType', () {
    test('should have all expected values', () {
      expect(StoreOfferType.values.length, equals(4));
      expect(StoreOfferType.introductory, isNotNull);
      expect(StoreOfferType.promotional, isNotNull);
      expect(StoreOfferType.freeTrial, isNotNull);
      expect(StoreOfferType.unknown, isNotNull);
    });
  });

  group('StorePeriodUnit', () {
    test('should have all expected values', () {
      expect(StorePeriodUnit.values.length, equals(5));
      expect(StorePeriodUnit.day, isNotNull);
      expect(StorePeriodUnit.week, isNotNull);
      expect(StorePeriodUnit.month, isNotNull);
      expect(StorePeriodUnit.year, isNotNull);
      expect(StorePeriodUnit.unknown, isNotNull);
    });
  });

  group('StorePaymentMode', () {
    test('should have all expected values', () {
      expect(StorePaymentMode.values.length, equals(4));
      expect(StorePaymentMode.payAsYouGo, isNotNull);
      expect(StorePaymentMode.payUpFront, isNotNull);
      expect(StorePaymentMode.freeTrial, isNotNull);
      expect(StorePaymentMode.unknown, isNotNull);
    });
  });

  group('StorePriceInfo', () {
    test('should store basic price details', () {
      const priceInfo = StorePriceInfo(
        currentPrice: 6.0,
        formattedPrice: '¥6.00',
        currencyCode: 'CNY',
        currencySymbol: '¥',
      );
      expect(priceInfo.currentPrice, equals(6.0));
      expect(priceInfo.formattedPrice, equals('¥6.00'));
      expect(priceInfo.currencyCode, equals('CNY'));
      expect(priceInfo.currencySymbol, equals('¥'));
      expect(priceInfo.symbolBeforePrice, equals(true));
      expect(priceInfo.pricePerMonth, isNull);
    });
  });

  group('StorePeriod', () {
    test('should store period details', () {
      const period = StorePeriod(value: 1, unit: StorePeriodUnit.month);
      expect(period.value, equals(1));
      expect(period.unit, equals(StorePeriodUnit.month));
    });
  });

  group('StoreProductInfo', () {
    test('should store basic product details', () {
      final productInfo = StoreProductInfo(
        id: 'product_001',
        nativeProductId: 'product_001',
        title: 'VIP Subscription',
        description: 'Monthly VIP subscription',
        type: StoreProductType.subscription,
        priceInfo: const StorePriceInfo(
          currentPrice: 6.0,
          formattedPrice: '¥6.00',
          currencyCode: 'CNY',
          currencySymbol: '¥',
        ),
        rawDetails: ProductDetails(
          id: 'product_001',
          title: 'VIP Subscription',
          description: 'Monthly VIP subscription',
          price: '¥6.00',
          rawPrice: 6.0,
          currencyCode: 'CNY',
          currencySymbol: '¥',
        ),
      );
      expect(productInfo.id, equals('product_001'));
      expect(productInfo.title, equals('VIP Subscription'));
      expect(productInfo.type, equals(StoreProductType.subscription));
      expect(productInfo.priceInfo.currentPrice, equals(6.0));
    });
  });
}
