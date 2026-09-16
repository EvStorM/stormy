## Unreleased

- 支付结果改用明确 PayStatus；微信发起与平台成功分离，支付宝签约回前台只发布待查询事件。
- 同平台禁止覆盖未结束订单；并发初始化合并、失败可重试，订阅由实例释放，销毁后默认入口创建新实例。
- 依赖 core/platform，移除 kit 与 UI 提示；主入口导出 Payment 类型。

兼容性与迁移见 [迁移说明](../../docs/MIGRATION.md)。

## 0.0.1

* TODO: Describe initial release.
