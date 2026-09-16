# stormy_china_pay

微信/支付宝支付、签约、授权和微信分享。依赖 core/platform，由宿主根据状态显示 UI。

初始化用 `StormyChinaPay().initWeChat(config)` / `initAlipay(config)`。先订阅 `paymentStream` 再支付；并发初始化共享结果，失败可重试。同平台当前订单不能被下一笔覆盖。

支付状态为 `launched`、`pending`、`platformSucceeded`、`cancelled`、`failed`。微信发起只返回 launched；支付宝签约回前台只发布 pending 查询提示。isSuccess 仅对应平台明确成功，权益必须向服务端核实。

dispose 终止当前实例，旧对象再次操作报错；重新获取默认入口创建新对象。测试使用 withAdapters 和 SDK 的 withAdapter。页面只释放自己的订阅。

完整初始化、宿主配置见 [使用指南](../../docs/USAGE.md)，兼容性见 [迁移说明](../../docs/MIGRATION.md)。
