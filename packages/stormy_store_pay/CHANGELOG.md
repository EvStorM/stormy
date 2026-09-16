## Unreleased

- 稳定事件流/notifier 支持初始化前订阅，平台转发先于初始化建立。
- 修复 Apple/Google 初始化 Future 无法结束和失败重试，忽略销毁后的迟到回调。
- 新增 purchaseAndWait，按 nativeProductId 匹配，拒绝同商品并发，处理发起失败、取消、超时及销毁。
- dispose 终止当前对象，默认入口重新创建；示例改为后端验单。

兼容性与迁移见 [迁移说明](../../docs/MIGRATION.md)。

## 1.0.0

* TODO: Describe initial release.
