# stormy_gromore 全广告类型示例

[`lib/main.dart`](lib/main.dart) 演示隐私同意、ATT、初始化、开屏、激励视频、插全屏、Banner、模板 Feed/Draw，以及预缓存、事件过滤、失败重试和视图移除。业务发奖与服务端 SSV 由宿主实现。

本目录提供独立 `pubspec.yaml` 和 Dart 页面，**不包含 Android/iOS runner**，不能直接在此执行 `flutter run`。

## 静态检查

从本目录运行：

```sh
fvm flutter pub get
fvm dart analyze lib
```

## 创建本地测试宿主

从 Stormy 仓库根目录执行（首次创建时使用新的目录）：

```sh
fvm flutter create --no-pub --platforms=android,ios --project-name=gromore_host temp/gromore-integration/host
```

在生成的 `temp/gromore-integration/host/pubspec.yaml` 的 `dependencies` 下添加：

```yaml
  stormy_gromore:
    path: ../../../packages/stormy_gromore
```

完成原生配置后，从该宿主目录运行后续命令。

## 原生配置

Android 宿主的 `android/build.gradle.kts` → `allprojects.repositories` 添加：

```kotlin
maven { url = uri("https://artifact.bytedance.com/repository/pangle") }
```

如果宿主采用集中仓库配置，将该仓库加入 `settings.gradle.kts` 的 `dependencyResolutionManagement.repositories`。Groovy 工程使用 `maven { url 'https://artifact.bytedance.com/repository/pangle' }`。

`android/app/build.gradle.kts` 使用 `minSdk = 24`，确保编译 SDK 至少为 36、Java 目标为 17。在宿主 Manifest 根节点添加 `xmlns:tools="http://schemas.android.com/tools"`，有 label 合并冲突时为 `<application>` 添加 `tools:replace="android:label"`。

iOS 使用 13.0 或更高 deployment target。插件提供 CocoaPods podspec；如果宿主启用了 Swift Package Manager，需保留 Flutter 对 CocoaPods 插件的兼容支持。请求 ATT 前，在 `ios/Runner/Info.plist` 添加符合实际用途的 `NSUserTrackingUsageDescription`。

两端都只自动引入 GroMore mediation core。额外广告联盟的 adapter/SDK、SKAdNetwork、微信跳转和宿主权限配置见 [插件说明](../README.md)，按控制台真实配置补齐。

## 运行与构建

在 `temp/gromore-integration/host/` 中执行：

```sh
fvm flutter pub get
fvm flutter run -t ../../../packages/stormy_gromore/example/lib/main.dart \
  --dart-define=GROMORE_ANDROID_APP_ID=your_android_app_id \
  --dart-define=GROMORE_IOS_APP_ID=your_ios_app_id \
  --dart-define=GROMORE_SPLASH_SLOT_ID=your_splash_slot_id \
  --dart-define=GROMORE_REWARDED_SLOT_ID=your_rewarded_slot_id \
  --dart-define=GROMORE_INTERSTITIAL_SLOT_ID=your_interstitial_slot_id \
  --dart-define=GROMORE_BANNER_SLOT_ID=your_banner_slot_id \
  --dart-define=GROMORE_FEED_SLOT_ID=your_feed_slot_id \
  --dart-define=GROMORE_DRAW_SLOT_ID=your_draw_slot_id
```

根据当前平台传入其 App ID 与相应的聚合广告位 ID。参数均从 Flutter 传入，不修改原生源码。先勾选隐私同意，再按平台需要请求 ATT、初始化 SDK，最后测试广告。

只验证编译时可不提供真实 ID，不安装或启动广告：

```sh
fvm flutter build apk --debug --target-platform android-arm64 -t ../../../packages/stormy_gromore/example/lib/main.dart
fvm flutter build ios --debug --no-codesign -t ../../../packages/stormy_gromore/example/lib/main.dart
```

无签名的 iOS 构建仅用于编译检查，真机运行需要宿主签名。编译成功不代表广告可填充；真实广告还需控制台配置、匹配的签名和设备验证。接入已有业务 App 时将依赖路径和 `-t` 路径改为相对该 App 的路径即可。
