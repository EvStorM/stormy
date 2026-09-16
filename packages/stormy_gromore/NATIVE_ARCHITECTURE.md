# 原生模块与资源归属

SDK 保持 Android `7.7.1.6`、iOS `7.8.0.3`。广告类型、Channel 名称、参数和事件字段，以及默认 6000ms 奖励回调保留策略均保持不变。

| 职责 | Android | iOS |
| --- | --- | --- |
| 引擎注册、方法分发、宿主协调 | StormyGromorePlugin | StormyGromorePlugin |
| 初始化、隐私、待完成结果 | GromoreInitialization | StormyGromoreInitialization / PrivacyProvider |
| 参数与首次预加载 | GromoreAdRequests / AdSlots | StormyGromoreAdRequests |
| 全屏广告与奖励保留计时 | GromoreFullScreenAds | StormyGromoreFullScreenAds |
| Banner、Feed、Draw 视图 | GromorePlatformViews | StormyGromorePlatformViews |
| 事件队列与发送 | GromoreEvents | StormyGromoreEvents |
| 终态与宿主有效性 | RewardTerminalState / FullScreenHostGuard | StormyRewardTerminalState / StormyCanPresentHost |

全屏模块持有其创建的广告对象、delegate/监听和释放计时器。平台视图持有自己的广告，工厂记录弱引用，在引擎释放时通知视图清理。iOS 预加载模块持有网络监视器和未结束的 FlutterResult，销毁时取消并结束调用。事件模块持有事件队列；销毁后的事件不再入队或发送。

奖励和关闭顺序都允许：已关闭但尚未收到奖励的广告在原保留期内继续接收一次奖励；重复回调忽略。资源释放后不再接受终态变化。实际奖励仍以广告 SDK 和业务后端核验为准。

从仓库根目录执行 `sh Script/test_ios_state.sh`，在 macOS Foundation 上编译运行同一份 Objective-C 终态逻辑，覆盖先关闭/先奖励、重复回调、保留期结束后释放、销毁和宿主失效。它不代替设备广告验收。

Android 宿主执行 `./gradlew :stormy_gromore:testDebugUnitTest :app:assembleDebug`。本轮验证宿主使用 JDK 17、Gradle 8.14、AGP 8.11.1、Kotlin 2.2.20，按 README 配置 Pangle Maven 和 Manifest 合并。插件构建体系未迁移。

iOS 宿主在新增源码后先 `pod install` 更新编译文件列表，再执行 `fvm flutter build ios --debug --no-codesign`。本轮继续使用 CocoaPods，未迁移 Swift Package Manager。真机广告填充、展示、奖励与服务端回调需单独验收。
