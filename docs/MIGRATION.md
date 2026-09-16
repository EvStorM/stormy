# 可靠性与拆包迁移

本轮不修改 Hive 编码、Bucket 名称、adapter typeId、GroMore Channel 或 SDK 版本，也不发布版本。

## 包入口

| 原路径/用途 | 新入口 |
| --- | --- |
| 网络、存储、日志、预加载、通用工具 | `package:stormy_core/stormy_core.dart` |
| 设备、安全存储、路径、图片、相册、原生权限 | `package:stormy_platform/stormy_platform.dart` |
| App、主题、弹窗、刷新、Widgets、WebView、权限提示 | `package:stormy_ui/stormy_ui.dart` |
| 统一配置与旧主入口 | `package:stormy_kit/stormy_kit.dart`，继续重导出以上能力 |
| 运行期语言状态 | `package:stormy_i18n/stormy_i18n.dart` |
| 文案 CLI/解析/ARB/脚手架 | 宿主的 `dev_dependencies` 添加 `stormy_i18n_generator` |

直接引用旧内部文件的宿主必须改成所属包入口；需要内部类型时，将路径中的包名改成所属包，目录层级不变。例如 `stormy_kit/core/storage/interfaces/storage_engine.dart` 改成 `stormy_core/core/storage/interfaces/storage_engine.dart`。

`StormyServices.networkClient` 位于 core；主题、资源与语言界面配置由 `StormyUiConfig` 持有。旧 `StormyConfigAccessor` 委托给这两个入口。UI 不反向依赖 kit，国内支付依赖 core/platform，不再自动展示 Toast。

生成命令迁移为 `fvm dart run stormy_i18n_generator init|gen|watch`，保留 `stormy_i18n.yaml`、源文案和生成文件路径。CLI 子进程失败返回非零退出码，watch 连续变更串行生成并合并等待中的变更。运行期包不依赖生成器；当前 Riverpod 自身仍通过 `test` 引入 analyzer，不能把拆包等同于彻底移除 analyzer。工作区 override 保留。

## 行为与兼容性

- 支付结果和事件构造器改用 `PayStatus`。微信请求发起只返回 `launched`；支付宝签约返回前台只发布 `pending`。`isSuccess` 仅对应 `platformSucceeded`，不证明服务端已经发放权益。同平台当前订单尚未结束时拒绝新订单。
- `StorePayManager` 流与 notifier 从创建到销毁保持身份；先订阅再初始化，可收到初始化期间的恢复事件。并发初始化共享结果，失败后允许重试。
- 推荐 `purchaseAndWait(product)`。按 `nativeProductId` 匹配，拒绝同商品并发，发起失败、取消、超时和销毁结束等待。底层 `purchaseProduct`/`waitForPurchase` 保留；恢复事件不会满足一次新购买等待。商店没有每次客户端调用的关联 ID，超时后重试时业务仍需通过后端交易 ID 去重。
- 支付 `dispose()` 终止当前对象；旧对象再次操作报错，重新获取默认实例创建新对象。页面只取消自己的订阅，停止服务时才销毁管理器。独立测试使用 `StormyChinaPay.withAdapters`、SDK 的 `withAdapter` 和 `StorePayManager.withFactory`。
- `apply()` 返回各已配置模块的状态、原异常与堆栈；`build()` 应用失败抛出携带报告的 `StormyInitializationException`。`isAllApplied` 只判断已配置模块，i18n 要求可用存储。失败初始化清理本次创建的资源。
- KV API 的键参数为 `Object`，运行时只接受 `String`、`int`；枚举为 `List<Object>`。前缀仅应用字符串，整数 `0` 与字符串 `"0"` 严格区分；批量删除、TTL 清理保留原类型。列表 ID 仍为字符串。
- 预加载等待异步 Provider 的数据或错误，成功后才统计完成。外部 `ProviderContainer` 由调用方释放，内部创建的容器由引擎释放。并发检查各自可取消；超时/取消会停止等待，普通 Dart Future 的底层操作仍需业务自行提供取消机制。

完整接入与资源归属见 [使用指南](USAGE.md)。真实支付、广告填充、平台奖励回调与服务端权益必须在设备和沙盒验收。

预加载任务图会拒绝重复 ID 和未注册依赖，错误进入失败结果与终态进度。预加载进度新增 `cancelledTasks`，`progress` 统计全部终态而非仅成功数；成功率使用执行结果的 `successRate`。
