# Stormy Store Pay

统一内购 SDK，支持 Google Play 和 Apple App Store 双平台内购。

## 功能特性

- **双平台支持**：自动根据平台选择对应的实现（Google Play / Apple App Store）
- **统一接口**：提供一致的购买、查询、恢复 API
- **平台扩展**：每个平台提供独立的扩展类，提供平台特有的功能
- **事件驱动**：同时支持 Stream 和回调两种事件通知方式
- **购买验证**：内置购买验证回调，支持服务器端验证集成
- **订阅支持**：支持 Google Play 订阅基础计划、优惠购买；Apple StoreKit 2 订阅优惠
- **沙盒/生产环境**：支持 Apple 沙盒环境测试配置

## 目录结构

```
lib/
├── stormy_store_pay.dart          # 主入口 barrel file
├── store_pay_manager.dart         # Facade 统一管理器（单例）
└── src/
    ├── store_pay_base.dart         # 抽象基类
    ├── store_pay_events.dart       # 事件模型
    ├── store_pay_types.dart        # 类型定义和枚举
    ├── store_pay_config.dart       # 配置类
    ├── google/
    │   ├── google_store_manager.dart      # Google Play 实现
    │   └── google_store_extension.dart    # Google 平台扩展
    └── apple/
        ├── apple_store_manager.dart       # Apple Store 实现
        ├── apple_store_extension.dart      # Apple 平台扩展
        └── apple_store_promo.dart         # Apple 促销码功能
```

## 快速开始

### 1. 添加依赖

```yaml
dependencies:
  stormy_store_pay: any
```

### 2. 初始化

```dart
import 'package:stormy_store_pay/stormy_store_pay.dart';

// 初始化
await StorePayManager.instance.initialize(
  verifier: (details) async {
    // 业务层验证购买凭证
    // 这里应该调用自己的服务器验证接口
    return true;
  },
);

// 设置回调
StorePayManager.instance.setCallbacks(
  onPurchaseSuccess: (event) {
    print('购买成功: ${event.productId}');
    if (event.isRestored) {
      print('这是恢复的购买');
    }
  },
  onPurchaseError: (error) {
    print('购买失败: ${error.message}');
  },
  onProductsLoaded: (products) {
    print('加载了 ${products.length} 个产品');
  },
  onPurchaseRestored: (event) {
    print('恢复购买: ${event.productId}');
  },
);
```

### 3. 查询产品

```dart
final products = await StorePayManager.instance.queryProducts([
  'product_monthly',
  'product_yearly',
  'coin_pack_small',
  'coin_pack_large',
]);
```

### 4. 购买产品

```dart
final product = StorePayManager.instance.getProduct('product_monthly');
if (product != null) {
  await StorePayManager.instance.purchaseProduct(product);
}
```

### 5. 恢复购买

```dart
await StorePayManager.instance.restorePurchases();
```

## 平台特定功能

### Google Play

通过 `StorePayManager.instance.googleExtension` 访问：

```dart
final googleExt = StorePayManager.instance.googleExtension;
if (googleExt != null) {
  // 查询订阅基础计划
  final basePlans = await googleExt.queryBasePlans(['subscription_id']);

  // 使用订阅优惠购买
  if (basePlans.isNotEmpty) {
    await googleExt.purchaseWithOffer(
      product,
      offerToken: basePlans.first.offerToken,
    );
  }

  // 消耗产品（如消耗型购买需要复用购买权）
  // await googleExt.consumePurchase(purchaseDetails);
}
```

### Apple App Store

通过 `StorePayManager.instance.appleExtension` 访问：

```dart
final appleExt = StorePayManager.instance.appleExtension;
if (appleExt != null) {
  // 查询 Apple 特有的产品信息（含 StoreKit 2 元数据）
  final appleProducts = await appleExt.queryAppleProductInfos(['product_id']);

  // 带数量的购买
  await appleExt.purchaseWithQuantity(product, quantity: 2);

  // 打开促销代码兑换界面
  await appleExt.presentCodeRedemptionSheet();
}
```

## 配置选项

```dart
await StorePayManager.instance.initialize(
  config: const StorePayConfig(
    autoCompletePurchases: true,  // 自动完成购买（默认 true）
    isForTest: false,             // 沙盒环境（仅 Apple）
    applicationUserName: 'user_123',  // 用户标识
  ),
  verifier: (details) async {
    return true;
  },
);
```

## 事件流

除了回调方式，也可以通过 Stream 监听事件：

```dart
// 购买成功
StorePayManager.instance.purchaseSuccessStream.listen((event) {
  print('购买成功: ${event.productId}');
});

// 购买错误
StorePayManager.instance.purchaseErrorStream.listen((error) {
  print('购买失败: ${error.message}');
});

// 产品加载
StorePayManager.instance.productsLoadedStream.listen((products) {
  print('加载了 ${products.length} 个产品');
});

// 购买恢复
StorePayManager.instance.purchaseRestoredStream.listen((event) {
  print('恢复购买: ${event.productId}');
});
```

## 类型定义

完整类型列表通过 `export 'package:stormy_store_pay/stormy_store_pay.dart'` 获得，包括：

- `IAPStatus` - 内购初始化状态
- `IAPPlatform` - 平台类型
- `IAPPurchaseLifecycle` - 购买生命周期
- `IAPPurchaseEvent` - 购买成功事件
- `IAPPurchaseErrorEvent` - 购买错误事件
- `StorePayConfig` - 配置类
- `PurchaseVerifier` - 购买验证回调类型定义
- `SubscriptionOfferInfo` - Google 订阅优惠信息
- `AppleProductInfo` - Apple 产品信息
- `AppleProductType` - Apple 商品类型
- `AppleSubscriptionOfferType` - Apple 订阅优惠类型
- `AppleSubscriptionOfferPaymentMode` - Apple 订阅扣费模式
- `AppleSubscriptionPeriodUnit` - Apple 订阅周期单位

## 注意事项

1. **购买验证**：生产环境中强烈建议实现服务器端购买验证，不要仅在客户端验证
2. **iOS 恢复购买**：Apple 要求所有 App 必须提供恢复购买功能
3. **沙盒测试**：iOS 沙盒测试需要在 Xcode 中配置 Sandbox 测试账号
4. **订阅测试**：Google Play 订阅测试需要添加测试账号；Apple 订阅测试需要沙盒账号
