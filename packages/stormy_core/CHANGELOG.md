## Unreleased

- 从 kit 提取网络、存储、日志、预加载和通用工具，默认网络实例归 StormyServices。
- KV 键保留 String/int 类型和字符串前缀，整数键参与枚举、删除及 TTL 清理；Hive 数据编码不变。
- 修复外部 ProviderContainer 归属、异步 Provider 完成、并发取消和终态进度，增加 cancelledTasks；任务图拒绝缺失依赖/重复 ID。

兼容性与迁移见 [迁移说明](../../docs/MIGRATION.md)。
