# Stormy Store Pay (`stormy_store_pay`) 双端内购 SDK

`stormy_store_pay` 提供了针对 Google Play 与 Apple App Store 双平台内购（IAP）与订阅的统一化高级封装，并抹平了复杂的底层监听回调和凭证交互。

---

## 1. 初始化内购管理器与服务器端验证 (`verifier`)

在 App 启动时，需要调用初始化。**必须**提供 `verifier` 回调函数。每次交易成功后，SDK 会自动将付款凭证投递给 `verifier`，由它调用您自己的后台进行支付安全核销，返回 `true` 后，SDK 才会核准此次购买（对于消耗型商品会自动核销，对于订阅或非消耗型商品会完成 Transaction），有效防范绕过客户端的 Receipt Replay 凭证重放攻击。

```dart
import 'package:stormy_store_pay/stormy_store_pay.dart';

await StorePayManager.instance.initialize(
  config: const StorePayConfig(
    autoCompletePurchases: true, // 自动核销消耗型或确认订单（默认为 true）
    isForTest: false,            // 设为 true 时，Apple 环境会自动切换为 Sandbox 沙盒测试
    applicationUserName: 'hash_user_id_1001', // 可选：传入用户标识哈希，供苹果/谷歌防欺诈检测
  ),
  // 必须配置的核销验证器
  verifier: (PurchaseDetails details) async {
    // 示例：将支付凭证上传至您自己的业务后台
    final bool verified = await myBackendService.verifyReceipt(
      productId: details.productId,
      receiptData: details.verificationData.serverVerificationData,
    );
    return verified; // 返回验证结果
  },
);
```

---

## 2. 查询、购买与同步等待 (`waitForPurchase`)

### 2.1 查询商品

```dart
// 查询指定 native 商品列表。
// 设置 autoRestorePurchases: true 可以顺便拉取已购订阅或非消耗型商品的持有状态并自动进行本地同步。
final List<StoreProductInfo> products = await StorePayManager.instance.queryProducts(
  ['sku_monthly_vip', 'sku_coins_100'],
  autoRestorePurchases: true, 
);
```

### 2.2 发起购买并同步等待结果

普通的购买是触发式的，返回调起成功（`true`）或失败。为了让购买代码能像网络请求一样优雅地被 `await` 直至完全核销，建议使用 `waitForPurchase`：

```dart
final product = StorePayManager.instance.getProduct('sku_monthly_vip');

if (product != null) {
  // 1. 发起购买请求
  final success = await StorePayManager.instance.purchaseProduct(product);
  
  if (success) {
    try {
      // 2. 同步挂起并等待购买与服务器 verifier 校验闭环（最长 5 分钟超时）
      final IAPPurchaseEvent event = await StorePayManager.instance.waitForPurchase(
        product.id,
        timeout: const Duration(minutes: 5),
      );
      print('购买成功且服务器核销通过: ${event.productId}');
    } catch (e) {
      print('购买流程失败或超时: $e');
    }
  }
}
```

---

## 3. 恢复购买 (Apple 审核硬性要求)

根据苹果应用商店 Review Guideline 3.1.1 要求，提供订阅和非消耗性商品的 iOS 应用必须在界面显式提供“恢复购买”按钮：

```dart
// 绑定至设置页或商店页的“恢复购买”按钮
await StorePayManager.instance.restorePurchases();
```

---

## 4. 平台特有扩展

### 4.1 Google Play 平台扩展 (`googleExtension`)

仅在 Android 下可用，支持查询基础订阅计划并应用 Offer 进行打折购买：

```dart
final googleExt = StorePayManager.instance.googleExtension;
if (googleExt != null) {
  // 查询订阅对应的 Google 基础计划 (Base Plans) 与折扣 offer
  final basePlans = await googleExt.queryBasePlans(['sku_monthly_vip']);
  
  if (basePlans.isNotEmpty) {
    // 传入 offerToken 发起折扣购买
    await googleExt.purchaseWithOffer(
      product,
      offerToken: basePlans.first.offerToken,
    );
  }
}
```

### 4.2 Apple App Store 平台扩展 (`appleExtension`)

仅在 iOS 下可用，支持 StoreKit 2 的高级功能及优惠码兑换：

```dart
final appleExt = StorePayManager.instance.appleExtension;
if (appleExt != null) {
  // 1. 查询 Apple 专属底层元数据 (如 StoreKit 2 的价格详情)
  final appleProducts = await appleExt.queryAppleProductInfos(['sku_coins_100']);
  
  // 2. 支持一次性购买多件商品
  await appleExt.purchaseWithQuantity(product, quantity: 3);
  
  // 3. 调起系统原生的促销优惠码/礼品卡兑换弹窗
  await appleExt.presentCodeRedemptionSheet();
}
```

---

## 5. UI 状态响应与事件流 (Streams)

`StorePayManager` 提供了直接用于 UI 构建的响应式状态和底层流：

### 5.1 响应式状态字段

*   `statusNotifier` / `status`：当前的 SDK 状态（`uninitialized`、`initializing`、`ready`、`error`）
*   `isLoadingNotifier` / `isLoading`：是否正在加载（拉取商品、处理支付中），可直接绑定用于转菊花的 HUD。
*   `products`：当前内存中已缓存的全部商品列表。
*   `purchasedProducts`：当前用户已购买且持有的有效非消耗型/订阅商品记录。
*   `errorMessage`：初始化或支付失败时留存的错误文案。

### 5.2 事件通知流

如果您倾向于在 App 顶层使用事件订阅来监听内购：

```dart
// 购买成功流
StorePayManager.instance.purchaseSuccessStream.listen((event) {
  print('支付核销成功: ${event.productId}');
});

// 支付报错流
StorePayManager.instance.purchaseErrorStream.listen((error) {
  print('购买异常: ${error.message}');
});

// 恢复购买成功流
StorePayManager.instance.purchaseRestoredStream.listen((event) {
  print('成功恢复了商品: ${event.productId}');
});
```
