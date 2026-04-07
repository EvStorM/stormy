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

    test('dispose should clear platform manager', () {
      StorePayManager.instance.dispose();
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

  group('AppleProductType', () {
    test('should have all expected values', () {
      expect(AppleProductType.values.length, equals(5));
      expect(AppleProductType.consumable, isNotNull);
      expect(AppleProductType.nonConsumable, isNotNull);
      expect(AppleProductType.nonRenewable, isNotNull);
      expect(AppleProductType.autoRenewable, isNotNull);
      expect(AppleProductType.unknown, isNotNull);
    });
  });

  group('AppleSubscriptionOfferType', () {
    test('should have all expected values', () {
      expect(AppleSubscriptionOfferType.values.length, equals(4));
      expect(AppleSubscriptionOfferType.introductory, isNotNull);
      expect(AppleSubscriptionOfferType.promotional, isNotNull);
      expect(AppleSubscriptionOfferType.winBack, isNotNull);
      expect(AppleSubscriptionOfferType.unknown, isNotNull);
    });
  });

  group('AppleSubscriptionPeriodUnit', () {
    test('should have all expected values', () {
      expect(AppleSubscriptionPeriodUnit.values.length, equals(5));
      expect(AppleSubscriptionPeriodUnit.day, isNotNull);
      expect(AppleSubscriptionPeriodUnit.week, isNotNull);
      expect(AppleSubscriptionPeriodUnit.month, isNotNull);
      expect(AppleSubscriptionPeriodUnit.year, isNotNull);
      expect(AppleSubscriptionPeriodUnit.unknown, isNotNull);
    });
  });

  group('SubscriptionOfferInfo', () {
    test('isBasePlan should return true when offerId is null', () {
      const offer = SubscriptionOfferInfo(
        offerId: null,
        basePlanId: 'base_plan_1',
        offerTags: [],
        offerToken: 'token_123',
        pricingPhases: [],
      );
      expect(offer.isBasePlan, isTrue);
    });

    test('isBasePlan should return false when offerId is set', () {
      const offer = SubscriptionOfferInfo(
        offerId: 'offer_1',
        basePlanId: 'base_plan_1',
        offerTags: [],
        offerToken: 'token_123',
        pricingPhases: [],
      );
      expect(offer.isBasePlan, isFalse);
    });

    test('hasFreeTrial should return true for zero price phase', () {
      const offer = SubscriptionOfferInfo(
        offerId: null,
        basePlanId: 'base_plan_1',
        offerTags: [],
        offerToken: 'token_123',
        pricingPhases: [
          PricingPhaseInfo(
            formattedPrice: '免费',
            priceCurrencyCode: 'CNY',
            priceAmountMicros: 0,
            billingCycleCount: 7,
            billingPeriod: 'P7D',
            recurrenceMode: 1,
          ),
        ],
      );
      expect(offer.hasFreeTrial, isTrue);
    });

    test('hasFreeTrial should return false for non-zero price phase', () {
      const offer = SubscriptionOfferInfo(
        offerId: null,
        basePlanId: 'base_plan_1',
        offerTags: [],
        offerToken: 'token_123',
        pricingPhases: [
          PricingPhaseInfo(
            formattedPrice: '¥6.00',
            priceCurrencyCode: 'CNY',
            priceAmountMicros: 6000000,
            billingCycleCount: 1,
            billingPeriod: 'P1M',
            recurrenceMode: 2,
          ),
        ],
      );
      expect(offer.hasFreeTrial, isFalse);
    });

    test('hasIntroductoryPrice should return true when multiple phases', () {
      const offer = SubscriptionOfferInfo(
        offerId: 'offer_1',
        basePlanId: 'base_plan_1',
        offerTags: [],
        offerToken: 'token_123',
        pricingPhases: [
          PricingPhaseInfo(
            formattedPrice: '¥1.00',
            priceCurrencyCode: 'CNY',
            priceAmountMicros: 1000000,
            billingCycleCount: 3,
            billingPeriod: 'P1M',
            recurrenceMode: 1,
          ),
          PricingPhaseInfo(
            formattedPrice: '¥6.00',
            priceCurrencyCode: 'CNY',
            priceAmountMicros: 6000000,
            billingCycleCount: 0,
            billingPeriod: 'P1M',
            recurrenceMode: 2,
          ),
        ],
      );
      expect(offer.hasIntroductoryPrice, isTrue);
    });
  });

  group('PricingPhaseInfo', () {
    test('price getter should convert micros to double', () {
      const phase = PricingPhaseInfo(
        formattedPrice: '¥6.00',
        priceCurrencyCode: 'CNY',
        priceAmountMicros: 6000000,
        billingCycleCount: 1,
        billingPeriod: 'P1M',
        recurrenceMode: 1,
      );
      expect(phase.price, equals(6.0));
    });

    test('isFree should return true for zero price', () {
      const phase = PricingPhaseInfo(
        formattedPrice: '免费',
        priceCurrencyCode: 'CNY',
        priceAmountMicros: 0,
        billingCycleCount: 7,
        billingPeriod: 'P7D',
        recurrenceMode: 1,
      );
      expect(phase.isFree, isTrue);
    });

    test('isInfiniteRecurring should return true for mode 2', () {
      const phase = PricingPhaseInfo(
        formattedPrice: '¥6.00',
        priceCurrencyCode: 'CNY',
        priceAmountMicros: 6000000,
        billingCycleCount: 0,
        billingPeriod: 'P1M',
        recurrenceMode: 2,
      );
      expect(phase.isInfiniteRecurring, isTrue);
    });

    test('isFiniteRecurring should return true for mode 1 with count > 0', () {
      const phase = PricingPhaseInfo(
        formattedPrice: '¥1.00',
        priceCurrencyCode: 'CNY',
        priceAmountMicros: 1000000,
        billingCycleCount: 3,
        billingPeriod: 'P1M',
        recurrenceMode: 1,
      );
      expect(phase.isFiniteRecurring, isTrue);
    });
  });

  group('InstallmentPlanInfo', () {
    test('should store installment details', () {
      const plan = InstallmentPlanInfo(
        commitmentPaymentsCount: 3,
        subsequentCommitmentPaymentsCount: 9,
      );
      expect(plan.commitmentPaymentsCount, equals(3));
      expect(plan.subsequentCommitmentPaymentsCount, equals(9));
    });
  });

  group('AppleProductInfo', () {
    test('should store product info', () {
      const productInfo = AppleProductInfo(
        productId: 'product_001',
        title: 'VIP Subscription',
        description: 'Monthly VIP subscription',
        displayPrice: '¥6.00',
        rawPrice: 6.0,
        currencyCode: 'CNY',
        currencySymbol: '¥',
        productType: AppleProductType.autoRenewable,
        subscriptionInfo: null,
      );
      expect(productInfo.productId, equals('product_001'));
      expect(productInfo.title, equals('VIP Subscription'));
      expect(productInfo.productType, equals(AppleProductType.autoRenewable));
    });
  });
}
