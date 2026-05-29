# Stormy China Pay (`stormy_china_pay`) 统一支付与国内分享 SDK

`stormy_china_pay` 提供了针对国内环境的微信（WeChat）与支付宝（Alipay）渠道的统一支付、静默分享、SSO 授权登录解决方案。

---

## 1. SDK 初始化

在发起任何支付调用前，需要配置并初始化 SDK：

```dart
import 'package:stormy_china_pay/stormy_china_pay.dart';

// 一键初始化微信与支付宝
await StormyChinaPay().initAll(
  weChatConfig: WechatConfig(
    appId: 'wx1234567890abcdef', 
    universalLink: 'https://yourdomain.com/uni/',
    miniProgramUsername: 'gh_xxxxxx', // 默认绑定的微信小程序原始 ID
  ),
  alipayConfig: AlipayConfig(
    scheme: 'youralipayappscheme', // iOS 支付宝回跳所用的 URL Scheme
  ),
);
```

---

## 2. 统一支付 API (`pay`)

`StormyChinaPay().pay(...)` 是支付的统一入口。

```dart
final PayResult result = await StormyChinaPay().pay(
  type: SDKPaymentType.weChat, // 微信: SDKPaymentType.weChat，支付宝: SDKPaymentType.alipay
  orderInfo: '...',            // 后端服务器签发的订单字符串
  weChatPayment: myPaymentObj, // 微信支付时必填，类型为 Fluwx 的 Payment 对象
  isAuth: false,               // 是否为支付宝签约授权支付（默认为 false）
);

if (result.isSuccess) {
  print('支付调起成功');
} else {
  print('支付失败原因: ${result.errorMessage}');
}
```

---

## 3. 渠道特有高级能力与底层细节

### 3.1 微信（WeChat）特有 API

微信 SDK 底层基于 `fluwx` 封装，除了基础支付，还包含：

*   **调起小程序**：
    ```dart
    // 打开指定小程序路径
    await StormyChinaPay().weChatSDK.openMiniProgram('/pages/index/index');
    ```
*   **小程序签约支付**：
    ```dart
    // 通过跳转至小程序完成免密签约支付，支付结果需通过监听流获取
    await StormyChinaPay().weChatSDK.signPay(
      'gh_xxxxxx',                   // 小程序原始 ID
      '/pages/pay/index?orderId=123', // 签约路径
      'order_signature_xxx',          // 签名数据
    );
    ```
*   **微信图片分享**：
    `shareImage` 支持智能多端处理：
    ```dart
    // 自动判断平台：Android 下会将 XFile 保存到相册并传递相册路径；iOS 下会自动生成 900x1200 缩略图通过 Uint8List 分享
    await StormyChinaPay().shareImage(
      imageFile, // XFile 类型
      scene: WeChatScene.session, // 微信会话(session) / 朋友圈(timeline) / 收藏(favorite)
    );
    
    // 或者直接分享网络图片 URL / 本地路径：
    await StormyChinaPay().weChatSDK.shareImageUrl('https://domain.com/share.png');
    ```

### 3.2 支付宝（Alipay）特有 API

支付宝 SDK 底层基于 `tobias` 封装，其具有以下底层特性：

*   **签约授权支付与生命周期防丢包监听 (`isAuth = true`)**：
    当设置 `isAuth: true` 时，SDK 会解析签约参数并通过 `launchUrl` 调起支付宝客户端。由于支付宝客户端对此种支付可能没有直接的 SDK 回包响应，`AlipaySDK` 内部会注册一个 **`AppLifecycleStatus` 监听器**。当用户在支付宝完成操作并切回 App（状态变为 `resumed`）时，SDK 会捕获该事件并向流中发送挂起的 `_pendingSignEvent` 事件（此时 `isSignType` 被标记为 `true`），从而实现流程闭环。
*   **支付宝 SSO 授权**：
    ```dart
    // 调起支付宝 SSO 登录授权
    await StormyChinaPay().alipaySDK.auth('apiname=com.alipay.account.auth&app_id=xxxx...');
    ```

---

## 4. 事件流监听 (Streams)

SDK 提供三大合并流，分别用来在页面中响应事件。特别地，SDK 提供了 **`listenXXXOnce` 一次性监听器**，在接收到第一个事件后，会自动取消流订阅，有效防御内存泄漏。

```dart
// 1. 支付事件监听 (收到后自动销毁监听器)
StormyChinaPay().listenPaymentOnce((PaymentEvent event) {
  if (event.isSuccess) {
    if (event.isSignType) {
      print('签约成功，订单串: ${event.orderInfo}');
    } else {
      print('普通支付成功');
    }
  } else {
    print('支付异常: ${event.errorMessage}');
  }
});

// 2. 授权事件监听
StormyChinaPay().listenAuthOnce((AuthEvent event) {
  if (event.isSuccess) {
    print('SSO 授权成功，授权数据: ${event.authInfo}');
  }
});

// 3. 分享事件监听
StormyChinaPay().listenShareOnce((ShareEvent event) {
  if (event.isSuccess) {
    print('图片分享成功');
  }
});
```

> [!WARNING]
> 如果不使用 `listenXXXOnce` 而是订阅了原始的 `paymentStream` / `shareStream` / `authStream`，开发者必须在 Widget 被销毁时手动调用 `subscription.cancel()` 来防止内存泄露。
