import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../store_pay_types.dart';

/// 将原生底层产品信息转换为全平台统一的 [StoreProductInfo]
class StoreProductMapper {
  /// 是否将该 productId 视作消耗型产品 (依据 Google 的注册配置)
  final bool Function(String productId) isConsumable;

  StoreProductMapper({required this.isConsumable});

  // ==================== 主入口 ====================

  /// 转换一组原生的商品组合。
  /// 注意，这将扁平化处理 Android 订阅结构。
  List<StoreProductInfo> mapProducts(List<ProductDetails> rawProducts) {
    final List<StoreProductInfo> results = [];
    for (final raw in rawProducts) {
      if (raw is AppStoreProduct2Details) {
        results.add(_mapAppleSk2(raw));
      } else if (raw is AppStoreProductDetails) {
        // 退化支持 StoreKit 1
        results.add(_mapAppleSk1(raw));
      } else if (raw is GooglePlayProductDetails) {
        results.addAll(_mapGoogle(raw));
      } else {
        // Fallback for unknown platform types
        results.add(_mapGeneric(raw));
      }
    }
    return results;
  }

  // ==================== APPLE 映射 ====================

  StoreProductInfo _mapAppleSk2(AppStoreProduct2Details raw) {
    final sk2 = raw.sk2Product;
    final type = _mapAppleProductType(sk2.type);

    final priceInfo = _buildPriceInfo(
      currentPrice: sk2.price,
      formattedPrice: raw.price,
      currencyCode: raw.currencyCode,
      currencySymbol: raw.currencySymbol,
      period: sk2.subscription != null
          ? _mapApplePeriod(sk2.subscription!.subscriptionPeriod)
          : null,
    );

    StoreSubscriptionInfo? subInfo;
    final List<StoreOfferInfo> offers = [];

    if (sk2.subscription != null) {
      final sub = sk2.subscription!;
      subInfo = StoreSubscriptionInfo(
        groupId: sub.subscriptionGroupID,
        period: _mapApplePeriod(sub.subscriptionPeriod),
        applePromotionalOffers: sub.promotionalOffers
            .map((o) => _mapAppleOffer(o, raw.currencyCode, raw.currencySymbol))
            .toList(),
      );

      // 提取 Introductory Offer (如果有的话)
      // 在 StoreKit 2 中，introductory offer 未被单列暴露，只在 promotionalOffers 里。如果有需要可以在原生端单独解析，这里略过。

      // 添加所有的促销优惠作为统一视图
      offers.addAll(
        sub.promotionalOffers.map(
          (o) => _mapAppleOffer(
            o,
            raw.currencyCode,
            raw.currencySymbol,
            forceType: StoreOfferType.promotional,
          ),
        ),
      );
    }

    return StoreProductInfo(
      id: raw.id,
      nativeProductId: raw.id,
      title: raw.title,
      description: raw.description,
      type: type,
      priceInfo: priceInfo,
      subscriptionInfo: subInfo,
      offers: offers,
      rawDetails: raw,
    );
  }

  StoreProductInfo _mapAppleSk1(AppStoreProductDetails raw) {
    // SK1 很多数据不足，为了向后兼容简易包装
    final sk1 = raw.skProduct;
    final bool hasSub = sk1.subscriptionPeriod != null;
    final type = isConsumable(raw.id)
        ? StoreProductType.consumable
        : (hasSub
              ? StoreProductType.subscription
              : StoreProductType.nonConsumable);

    final period = hasSub ? _mapSk1Period(sk1.subscriptionPeriod!) : null;
    final priceInfo = _buildPriceInfo(
      currentPrice: raw.rawPrice,
      formattedPrice: raw.price,
      currencyCode: raw.currencyCode,
      currencySymbol: raw.currencySymbol,
      period: period,
    );

    StoreSubscriptionInfo? subInfo;
    if (hasSub) {
      subInfo = StoreSubscriptionInfo(
        groupId: sk1.subscriptionGroupIdentifier ?? raw.id,
        period: period!,
      );
    }

    return StoreProductInfo(
      id: raw.id,
      nativeProductId: raw.id,
      title: raw.title,
      description: raw.description,
      type: type,
      priceInfo: priceInfo,
      subscriptionInfo: subInfo,
      rawDetails: raw,
    );
  }

  // ==================== GOOGLE 映射 ====================

  /// Google 的一个 Product 可能对应多个 BasePlan。我们将它展平。
  List<StoreProductInfo> _mapGoogle(GooglePlayProductDetails raw) {
    final type = isConsumable(raw.id)
        ? StoreProductType.consumable
        : (raw.productDetails.subscriptionOfferDetails != null
              ? StoreProductType.subscription
              : StoreProductType.nonConsumable);

    if (type != StoreProductType.subscription) {
      // 一次性/消耗型商品
      final priceInfo = _buildPriceInfo(
        currentPrice: raw.rawPrice,
        formattedPrice: raw.price,
        currencyCode: raw.currencyCode,
        currencySymbol: raw.currencySymbol,
      );
      return [
        StoreProductInfo(
          id: raw.id,
          nativeProductId: raw.id,
          title: raw.title,
          description: raw.description,
          type: type,
          priceInfo: priceInfo,
          rawDetails: raw,
        ),
      ];
    }

    // 处理订阅商品
    final results = <StoreProductInfo>[];
    final offersRaw = raw.productDetails.subscriptionOfferDetails ?? [];

    // 找出所有 basePlan (offerId 为 null 的是 basePlan 自身)
    final basePlans = offersRaw
        .where((o) => o.offerId == null || o.offerId!.isEmpty)
        .toList();

    // 如果一个都没有，退化成单个商品（几乎不可能）
    if (basePlans.isEmpty) {
      // fallback...
      return [];
    }

    for (final basePlan in basePlans) {
      final basePlanId = basePlan.basePlanId;
      final pricingPhase = basePlan.pricingPhases.isNotEmpty
          ? basePlan.pricingPhases.first
          : null;
      if (pricingPhase == null) continue; // 不合法的数据

      final currentPrice = pricingPhase.priceAmountMicros / 1000000.0;
      final period = _parseIso8601Period(pricingPhase.billingPeriod);

      final priceInfo = _buildPriceInfo(
        currentPrice: currentPrice,
        formattedPrice: pricingPhase.formattedPrice,
        currencyCode: pricingPhase.priceCurrencyCode,
        // 这里需要手动提取货币符号（Google SDK 不返回 standalone symbol）
        currencySymbol: _extractCurrencySymbol(pricingPhase.formattedPrice),
        period: period,
      );

      // 提取针对该 basePlan 的 Offers
      final offerInfos = <StoreOfferInfo>[];
      final relatedOffers = offersRaw.where(
        (o) =>
            o.offerId != null &&
            o.offerId!.isNotEmpty &&
            o.basePlanId == basePlanId,
      );

      for (final ro in relatedOffers) {
        if (ro.pricingPhases.isEmpty) continue;
        final phase = ro.pricingPhases.first; // 简单起见只取第一阶段

        final isFree = phase.priceAmountMicros == 0;
        final offerType = isFree
            ? StoreOfferType.freeTrial
            : StoreOfferType.introductory;
        final paymentMode = isFree
            ? StorePaymentMode.freeTrial
            : StorePaymentMode.payAsYouGo;

        offerInfos.add(
          StoreOfferInfo(
            id: ro.offerIdToken, // Google 用 offerIdToken 发起购买
            type: offerType,
            priceInfo: _buildPriceInfo(
              currentPrice: phase.priceAmountMicros / 1000000.0,
              formattedPrice: phase.formattedPrice,
              currencyCode: phase.priceCurrencyCode,
              currencySymbol: _extractCurrencySymbol(phase.formattedPrice),
              period: _parseIso8601Period(phase.billingPeriod),
            ),
            period: _parseIso8601Period(phase.billingPeriod),
            paymentMode: paymentMode,
            paymentCount: phase.billingCycleCount > 0
                ? phase.billingCycleCount
                : 1,
          ),
        );
      }

      final extSubInfo = StoreSubscriptionInfo(
        groupId: raw.id,
        period: period,
        googleBasePlanId: basePlanId,
        googleOfferTags: basePlan.offerTags.toList(),
      );

      results.add(
        StoreProductInfo(
          id: '${raw.id}:$basePlanId', // UI 用冒号拼接作唯一 ID
          nativeProductId: raw.id,
          title: raw.title,
          description: raw.description,
          type: type,
          priceInfo: priceInfo,
          subscriptionInfo: extSubInfo,
          offers: offerInfos,
          rawDetails: raw,
          googleDefaultOfferToken:
              basePlan.offerIdToken, // 买 base plan 的默认 token
        ),
      );
    }

    return results;
  }

  // ==================== GENERIC ====================
  StoreProductInfo _mapGeneric(ProductDetails raw) {
    final type = isConsumable(raw.id)
        ? StoreProductType.consumable
        : StoreProductType.unknown;
    return StoreProductInfo(
      id: raw.id,
      nativeProductId: raw.id,
      title: raw.title,
      description: raw.description,
      type: type,
      priceInfo: _buildPriceInfo(
        currentPrice: raw.rawPrice,
        formattedPrice: raw.price,
        currencyCode: raw.currencyCode,
        currencySymbol: raw.currencySymbol,
      ),
      rawDetails: raw,
    );
  }

  // ==================== 工具与转换 ====================

  /// 价格信息的标准化构建器，它会在此处解析符号前后、均价等！
  StorePriceInfo _buildPriceInfo({
    required double currentPrice,
    required String formattedPrice,
    required String currencyCode,
    required String currencySymbol,
    StorePeriod? period,
  }) {
    // 决定符号在前还是在后
    bool symbolBefore = true;
    final symbolIndex = formattedPrice.indexOf(currencySymbol);
    if (symbolIndex > -1 && symbolIndex > formattedPrice.length / 2) {
      symbolBefore = false;
    } else if (currencySymbol.isEmpty &&
        formattedPrice.endsWith(currencyCode)) {
      symbolBefore = false;
    }

    double? pD, pW, pM, pY;
    if (period != null && currentPrice > 0) {
      double annualPrice = currentPrice;
      switch (period.unit) {
        case StorePeriodUnit.day:
          annualPrice = currentPrice * 365 / period.value;
          break;
        case StorePeriodUnit.week:
          annualPrice = currentPrice * 52 / period.value;
          break;
        case StorePeriodUnit.month:
          annualPrice = currentPrice * 12 / period.value;
          break;
        case StorePeriodUnit.year:
          annualPrice = currentPrice / period.value;
          break;
        case StorePeriodUnit.unknown:
          break;
      }

      if (period.unit != StorePeriodUnit.unknown) {
        pY = annualPrice;
        pM = annualPrice / 12.0;
        pW = annualPrice / 52.0;
        pD = annualPrice / 365.0;
      }
    }

    return StorePriceInfo(
      currentPrice: currentPrice,
      formattedPrice: formattedPrice,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      symbolBeforePrice: symbolBefore,
      pricePerDay: pD,
      pricePerWeek: pW,
      pricePerMonth: pM,
      pricePerYear: pY,
    );
  }

  StoreProductType _mapAppleProductType(SK2ProductType type) {
    switch (type) {
      case SK2ProductType.consumable:
        return StoreProductType.consumable;
      case SK2ProductType.nonConsumable:
        return StoreProductType.nonConsumable;
      case SK2ProductType.nonRenewable:
        return StoreProductType.subscription;
      case SK2ProductType.autoRenewable:
        return StoreProductType.subscription;
    }
  }

  StorePeriod _mapApplePeriod(SK2SubscriptionPeriod period) {
    StorePeriodUnit u;
    switch (period.unit) {
      case SK2SubscriptionPeriodUnit.day:
        u = StorePeriodUnit.day;
        break;
      case SK2SubscriptionPeriodUnit.week:
        u = StorePeriodUnit.week;
        break;
      case SK2SubscriptionPeriodUnit.month:
        u = StorePeriodUnit.month;
        break;
      case SK2SubscriptionPeriodUnit.year:
        u = StorePeriodUnit.year;
        break;
    }
    return StorePeriod(value: period.value, unit: u);
  }

  StoreOfferInfo _mapAppleOffer(
    SK2SubscriptionOffer offer,
    String currencyCode,
    String currencySymbol, {
    StoreOfferType? forceType,
  }) {
    StoreOfferType type = forceType ?? StoreOfferType.promotional;
    if (forceType == null) {
      switch (offer.type) {
        case SK2SubscriptionOfferType.introductory:
          type = StoreOfferType.introductory;
          break;
        case SK2SubscriptionOfferType.promotional:
          type = StoreOfferType.promotional;
          break;
        case SK2SubscriptionOfferType.winBack:
          type = StoreOfferType.unknown;
          break;
      }
    }

    StorePaymentMode mode = StorePaymentMode.unknown;
    switch (offer.paymentMode) {
      case SK2SubscriptionOfferPaymentMode.payAsYouGo:
        mode = StorePaymentMode.payAsYouGo;
        break;
      case SK2SubscriptionOfferPaymentMode.payUpFront:
        mode = StorePaymentMode.payUpFront;
        break;
      case SK2SubscriptionOfferPaymentMode.freeTrial:
        mode = StorePaymentMode.freeTrial;
        break;
    }

    final period = _mapApplePeriod(offer.period);

    // TODO: 苹果原始未暴露 formattedPrice，简单拼接
    final fakeFormatted = mode == StorePaymentMode.freeTrial
        ? 'Free'
        : '$currencySymbol${offer.price}';

    return StoreOfferInfo(
      id: offer.id ?? offer.type.name,
      type: type,
      priceInfo: _buildPriceInfo(
        currentPrice: offer.price,
        formattedPrice: fakeFormatted,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
        period: period,
      ),
      period: period,
      paymentMode: mode,
      paymentCount: offer.periodCount,
    );
  }

  StorePeriod _mapSk1Period(SKProductSubscriptionPeriodWrapper period) {
    StorePeriodUnit u;
    switch (period.unit) {
      case SKSubscriptionPeriodUnit.day:
        u = StorePeriodUnit.day;
        break;
      case SKSubscriptionPeriodUnit.week:
        u = StorePeriodUnit.week;
        break;
      case SKSubscriptionPeriodUnit.month:
        u = StorePeriodUnit.month;
        break;
      case SKSubscriptionPeriodUnit.year:
        u = StorePeriodUnit.year;
        break;
    }
    return StorePeriod(value: period.numberOfUnits, unit: u);
  }

  /// ISO 8601 解析 (e.g. P1M, P1W, P3D)
  StorePeriod _parseIso8601Period(String isoPeriod) {
    if (isoPeriod.isEmpty)
      return const StorePeriod(value: 0, unit: StorePeriodUnit.unknown);

    isoPeriod = isoPeriod.toUpperCase();
    if (!isoPeriod.startsWith('P'))
      return const StorePeriod(value: 0, unit: StorePeriodUnit.unknown);

    final RegExp regex = RegExp(r'^P(\d+)([YMWD])$');
    final match = regex.firstMatch(isoPeriod);
    if (match != null) {
      final value = int.tryParse(match.group(1) ?? '1') ?? 1;
      final typeStr = match.group(2);
      StorePeriodUnit unit = StorePeriodUnit.unknown;
      if (typeStr == 'Y')
        unit = StorePeriodUnit.year;
      else if (typeStr == 'M')
        unit = StorePeriodUnit.month;
      else if (typeStr == 'W')
        unit = StorePeriodUnit.week;
      else if (typeStr == 'D')
        unit = StorePeriodUnit.day;

      return StorePeriod(value: value, unit: unit);
    }

    return const StorePeriod(value: 0, unit: StorePeriodUnit.unknown);
  }

  String _extractCurrencySymbol(String formattedPrice) {
    // 移除非数字符号部分，这在不同国家有复杂的正则，这里简单过滤数字和常见分隔符
    final regex = RegExp(r'[0-9\.,\s]+');
    final symbol = formattedPrice.replaceAll(regex, '').trim();
    return symbol.isNotEmpty ? symbol : '';
  }
}
