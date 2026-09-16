## Unreleased

- 保留旧主入口重导出，配置编排委托 core/platform/UI。
- 仅校验已配置模块及其依赖，apply 返回包含原异常/堆栈的报告，build 在应用失败时抛出 StormyInitializationException。

兼容性与迁移见 [迁移说明](../../docs/MIGRATION.md)。

## 1.1.0
- `StormyApp` 现在会等待基础初始化完成，并使用 `AppModel.designSize`
- `AppModel` 支持配置屏幕方向；传入空列表时由系统管理方向
- `StormyNetworkClient` 新增保留原始 `ResponseBody` 的 `requestStream` API
- cancel tag 在请求或响应流结束后自动释放，等待全局鉴权时也可立即取消
- 升级 `stormy_i18n` 0.1，兼容 analyzer 14 与 Hive CE 代码生成
- 兼容 Flutter 3.47 的核心 Material API 与 Dio 5.11 timeout 类型

## 1.0.2
- 集成了 `stormy_i18n` 模块，新增 `StormyI18nConfig` 提供全局国际化配置与支持

## 1.0.1
- 修复了一些问题

## 1.0.0
- 初始版本
