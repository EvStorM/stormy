# 可靠性与模块化改造验证记录

验证日期：2026-09-16。使用 `.fvmrc` 指定的 Flutter 3.47.1、Dart 3.13.1。

## 完成范围

按可靠性、事件 API 与文档、依赖拆分、原生整理的顺序完成本地修改与验证。保留原有用户改动，未执行提交、推送、发布或版本升级。

- 支付区分发起、等待、平台成功、取消和失败；初始化可合并、失败可重试，销毁后拒绝操作并忽略迟到回调。
- StorePay 事件流和 notifier 身份稳定，支持初始化前订阅；新增先监听后发起的 `purchaseAndWait()`。
- 预加载明确容器归属，等待异步 Provider，修复独立取消与终态统计；配置初始化报告保留模块状态、原始异常和堆栈。
- 存储保留整数与字符串键的区别，不改写 Hive 数据、Bucket 或 adapter typeId。
- workspace 拆为九包，保留 kit 主入口；i18n 生成器改为宿主开发依赖，修复失败退出码与 watch 串行生成。
- GroMore 两端拆分注册分发、初始化隐私、参数预加载、全屏广告、平台视图及事件发送；保持原 SDK、Channel 协议与奖励回调保留策略。

API 兼容性、调用迁移和资源归属见 [迁移说明](MIGRATION.md)，接入示例见 [使用指南](USAGE.md)，原生职责见 [GroMore 原生结构](../packages/stormy_gromore/NATIVE_ARCHITECTURE.md)。

## 基线与 Dart 验证

重新解析依赖，修复仓内生成缓存的旧 SDK 路径。原始五包测试共 61 项通过；基线 kit 静态检查有 36 条诊断，国内支付有 3 条诊断。原始差异保存在本地 `temp/reliability/baseline.patch`，基线日志为 `temp/reliability/*-baseline-*.log`。

最终九包测试共 **91 项通过**：

| 包 | 测试数量 | 静态检查 |
| --- | ---: | --- |
| stormy_core | 18 | 无 error/warning |
| stormy_platform | 1 | 无 error/warning |
| stormy_ui | 4 | 无 error/warning |
| stormy_kit | 2 | 无 error/warning |
| stormy_i18n | 1 | 无 error/warning |
| stormy_i18n_generator | 6 | 无 error/warning |
| stormy_china_pay | 8 | 无 error/warning |
| stormy_store_pay | 33 | 无 error/warning |
| stormy_gromore | 18 | 无 error/warning |

Flutter 包在各包目录运行 `fvm flutter test --no-pub`、`fvm flutter analyze --no-pub --no-fatal-infos`；生成器运行 `fvm dart test`、`fvm dart analyze`。最终根目录也执行了 `fvm flutter analyze --no-pub --no-fatal-infos`：**没有 error/warning，仍有 82 条 info 级提示**，包括已有的弃用 API 与代码风格提示；此次未将全部 lint 清理混入改造。

回归覆盖了发起与成功的区别、签约恢复前台、并发初始化和失败重试、销毁后的迟到回调、初始化前订阅和初始化期间事件、快速购买回调、同商品并发拒绝、取消、超时及销毁终止等待、验单失败不报告成功、外部 ProviderContainer 仍可使用、Provider 完成统计，以及整数/字符串键并存、删除、TTL 清理和 Hive 重开。

生成器测试覆盖子进程退出码 42 的传播、连续变更串行执行和合并、失败后重试、现有文案及 ICU 输出。两个现有示例均实际重新生成；kit 源文案字段由 `zhCN/enUS` 对齐 YAML 的 `zh_CN/en_US` 后生成，保持原 ARB 文案及 ICU 内容。

本地详细结果：`temp/reliability/final-results.json`、`temp/reliability/stormy_*-final-{test,analyze}.log` 和 `temp/reliability/root-final-analyze.log`。

## 依赖、示例与格式

以下检查均已执行：

```sh
fvm flutter pub get
python3 Script/check_dependencies.py
python3 Script/check_docs.py --dart /Users/mac/fvm/versions/3.47.1/bin/dart
python3 Script/check_runtime_host.py --flutter /Users/mac/fvm/versions/3.47.1/bin/flutter
python3 .agents/skills/stormy-helper/scripts/i18n_tool.py gen --path packages/stormy_i18n/example
git diff --check
```

- 九包依赖边界检查通过，下层包无 kit 反向导入。
- README、使用指南、迁移说明和预加载说明中的 **10 段完整 Dart 示例编译检查通过**。局部代码片段不作为独立程序编译。
- 在 workspace 外分别创建 core、旧 kit 主入口、新 UI 入口三个最小宿主，依赖解析与静态检查均通过，运行期依赖均不包含 `stormy_i18n_generator`。
- 根目录 analyzer override 保留：当前 Riverpod 自身仍经 `test` 引入 analyzer，拆包不等于彻底移除 analyzer。
- helper 的生成命令实际运行通过，更新后的 skill 通过结构校验。
- 本次修改及新增的 **144 个非生成 Dart 文件**通过 `dart format --output=none --set-exit-if-changed`，Diff 空白检查通过。两个自动生成的本地化脚手架文件保持生成器原始输出；原有 GroMore Dart 文件未修改，不纳入本次格式调整。

上述 SDK 绝对路径对应本机 FVM 安装位置；其他机器应传入本地同版本 SDK 路径。仓外最小宿主由脚本输出实际目录，未纳入 workspace。

## 原生状态与构建

原生宿主位于本地 `temp/reliability/native_host`，只装载插件，不使用真实广告凭证初始化 SDK。宿主启动的 1 项 widget smoke test 通过，单独记录于 `temp/reliability/host-smoke-test.log`，不计入九包的 91 项测试。

### Android

在宿主 `android` 目录执行：

```sh
JAVA_HOME=/Users/mac/Library/Java/JavaVirtualMachines/jbr-17.0.14/Contents/Home \
  ./gradlew :stormy_gromore:testDebugUnitTest :app:assembleDebug --stacktrace
```

结果：**4 项原生状态测试通过，debug APK 构建成功**。覆盖奖励/关闭顺序、重复回调、资源释放与宿主失效检查。日志：`temp/reliability/android-gradle.log`；JUnit XML 位于宿主 `build/stormy_gromore/test-results/testDebugUnitTest/`。

本机默认 JDK 25 不兼容现有 Gradle，构建时仅通过命令环境选择已安装的 JDK 17。临时宿主使用 Gradle 8.14、AGP 8.11.1、Kotlin 2.2.20、minSdk 24，配置 Pangle 仓库和 manifest label 合并；未迁移插件 Kotlin 构建体系，未升级广告 SDK。

产物：`temp/reliability/native_host/build/app/outputs/flutter-apk/app-debug.apk`。

### iOS

```sh
sh Script/test_ios_state.sh
# 在临时宿主 ios 目录运行 pod install 后，在宿主目录执行：
fvm flutter build ios --debug --no-codesign
```

结果：**Foundation 终态测试通过，iOS 无签名宿主构建成功**。终态测试直接编译实际使用的 Objective-C 状态模块，检查奖励/关闭两种顺序、重复回调、超时释放、销毁后回调与宿主有效性。测试在 macOS 上运行，不等于 iOS 设备行为验证。

日志：`temp/reliability/ios-state-test.log`、`temp/reliability/ios-build.log`。产物：`temp/reliability/native_host/build/ios/iphoneos/Runner.app`。保持 CocoaPods 接入，未迁移 Swift Package Manager。

## 设备验收项

以下尚未验证，不能由模拟测试或构建成功替代：

- 微信、支付宝真机拉起、取消、签约恢复前台，以及服务端异步通知和权益确认。
- StoreKit / Google Play 沙盒真实交易、恢复购买、订阅变化与后端验单；宿主需提供真实后端验证地址和用户身份绑定。
- GroMore 真机广告填充、展示、点击、奖励和关闭的真实 SDK 回调，以及前后台切换和宿主销毁时的设备表现。

`isSuccess` 仅说明平台明确报告成功；业务仍必须以后端验证与交易去重作为发放权益的依据。
