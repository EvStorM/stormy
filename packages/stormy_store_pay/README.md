# stormy_store_pay

Apple App Store / Google Play 内购。Flutter 3.47.1，Dart >=3.13。

先订阅 `StorePayManager.instance.purchaseSuccessStream`、`purchaseErrorStream`、`purchaseRestoredStream`，再调用 `initialize(verifier: verifyOnServer)`。流和 notifier 在同一实例内保持稳定，初始化期间的恢复事件也会转发。并发初始化共享结果，失败可重试。

`verifyOnServer` 必须请求后端验证收据/token、绑定用户并幂等记录交易。验单失败不得报告成功或完成交易。完整可编译示例见 [支付页](example/lib/store_pay_page.dart) 和 [后端请求实现](example/lib/receipt_verifier.dart)，后者通过 `PURCHASE_VERIFICATION_URL` 配置 HTTPS 服务；宿主应接入自己的登录会话。后端响应为 `{"verified": true}` 才接受，客户端不保存商店服务端密钥。

查询使用 `queryProducts(ids)`。购买推荐 `purchaseAndWait(product, offer: offer)`：先监听再发起、按 `nativeProductId` 匹配，同商品并发请求拒绝，取消/发起失败/超时/销毁会结束等待。`purchaseProduct` 返回值只代表请求发起；低层 `waitForPurchase` 保留，必须先监听再发起。权益以服务端为准。

页面释放自己的订阅；`await manager.dispose()` 终止服务实例，旧对象再次使用报错，重新读取 `StorePayManager.instance` 创建新对象。测试可用 `withFactory` 注入适配器。平台扩展在真实平台初始化成功后提供。

更多接入、恢复和沙盒说明见 [使用指南](../../docs/USAGE.md)。
