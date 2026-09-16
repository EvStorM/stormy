# stormy_gromore

`stormy_gromore` 是面向 Android/iOS 的 Flutter GroMore（穿山甲聚合）桥接插件。所有运行期广告配置均由 Flutter 传入：GroMore App ID、聚合广告位 ID、奖励信息、展示尺寸、方向、音量、预加载网络策略及隐私开关不会写死在原生代码中。

当前支持：

- 开屏广告
- 激励视频
- 插全屏广告
- Banner 原生平台视图
- 模板信息流（Feed）原生平台视图
- 模板 Draw 信息流原生平台视图
- Splash、激励视频、插全屏、Feed 的 GroMore 首次预缓存，可选择仅 WiFi 或任意网络
- ATT 请求、统一事件流、奖励校验结果和展示后 eCPM 信息

SDK 版本固定为 Android GroMore `7.7.1.6`、iOS `Ads-CN-Beta/CSJMediation-Only 7.8.0.3`。升级核心 SDK 或任一 ADN 时，请重新核对 GroMore 控制台兼容矩阵并整组锁定版本。

## 添加依赖

本包已加入 Stormy 根目录 `pubspec.yaml` 的 workspace。仓库内其他 workspace 成员按需声明 `stormy_gromore: any`；仓库外的 Flutter 宿主使用相对本地路径，例如与 `stormy` 仓库同级时：

```yaml
dependencies:
  stormy_gromore:
    path: ../stormy/packages/stormy_gromore
```

完整交互示例位于 [`example/lib/main.dart`](example/lib/main.dart)，包含六类广告、事件过滤、失败重试与 PlatformView 主动移除。示例仅包含 Dart 页面，需要 Android/iOS 宿主；创建宿主的步骤及全部 `dart-define` 参数见 [`example/README.md`](example/README.md)。五个包的协作与生命周期见 [项目使用指南](../../docs/USAGE.md)。

## 合规初始化

只有在用户同意应用隐私政策后才能初始化。ATT 由宿主决定请求时机，插件不会在注册时自动弹窗或自动启动 SDK。

```dart
import 'dart:async';

import 'package:stormy_gromore/stormy_gromore.dart';

final StormyGromore gromore = StormyGromore.instance;

Future<void> initializeAds() async {
  final GromoreTrackingStatus tracking =
      await gromore.requestTrackingAuthorization();

  await gromore.initialize(
    GromoreConfig(
      appIds: const GromoreAppIds(
        android: String.fromEnvironment('GROMORE_ANDROID_APP_ID'),
        ios: String.fromEnvironment('GROMORE_IOS_APP_ID'),
      ),
      appName: 'Stormy Demo',
      debug: false,
      // 应比 Dart 业务层等待奖励回调的 grace period 更长。
      rewardCallbackRetention: const Duration(seconds: 6),
      privacy: GromorePrivacyConfig(
        canUseIdfa: tracking == GromoreTrackingStatus.authorized,
        // 只有取得对应授权后才把其他能力改为 true。
      ),
    ),
  );
}
```

`GromorePrivacyConfig` 默认拒绝采集并限制个性化/程序化广告。Android 与 iOS 能力并不完全相同；不适用于当前平台的字段会被忽略。`requestTrackingAuthorization()` 在 Android 返回 `notSupported`。

## 全屏类广告

### 开屏

```dart
final String splashId = await gromore.loadSplash(
  const GromoreSplashRequest(
    slotId: String.fromEnvironment('GROMORE_SPLASH_SLOT_ID'),
    autoShow: true,
  ),
);

// autoShow: false 时，收到 loaded 事件后再调用：
await gromore.showSplash(splashId);
```

### 激励视频

```dart
final String rewardedId = await gromore.loadRewarded(
  const GromoreRewardedRequest(
    slotId: String.fromEnvironment('GROMORE_REWARDED_SLOT_ID'),
    userId: 'flutter-user-id',
    customData: '{"source":"practice"}',
    rewardName: '能量',
    rewardAmount: 1,
  ),
);

// 收到该 requestId 的 loaded 事件后展示。
await gromore.showRewarded(rewardedId);
```

业务发奖应以 `rewardEarned`（或服务端 SSV）为准，不能把视频播放完成当作奖励成功。

少数 ADN 会在 `closed` 之后才返回 `rewardEarned` / `rewardFailed`。插件会在关闭后短暂保留该广告与原 `requestId` 的关联：奖励结果到达后立即释放；若结果未到达，则在 `GromoreConfig.rewardCallbackRetention` 结束时释放（默认 6 秒）。该值必须长于业务层等待奖励回调的 grace period；例如业务层等待 5.5 秒时，默认值会晚 0.5 秒释放。关闭时仍需保留业务事件关联，不能立刻取消奖励订阅或手动释放该请求。奖励结果与 `closed` 都会去重，最终以 `disposed` 表示原生对象已释放。Android 展示期间若宿主 Activity 销毁、配置变更或 detach，激励和插全屏广告也会进入关闭终态，避免悬挂请求。

Android 只有在宿主 Activity 已 resumed 且未处于 finishing/destroyed 状态时才允许展示开屏、激励或插全屏广告。前台条件不满足时 `show*` 返回 `activity_unavailable`，已加载广告仍保持 ready，可在回到前台后再次展示；后台完成加载的 `autoShow` 开屏会等到 Activity resumed。

### 插全屏

```dart
final String interstitialId = await gromore.loadInterstitial(
  const GromoreInterstitialRequest(
    slotId: String.fromEnvironment('GROMORE_INTERSTITIAL_SLOT_ID'),
  ),
);

// 收到 loaded 后展示。
await gromore.showInterstitial(interstitialId);
```

不再使用且尚未进入关闭终态的全屏广告可显式释放：

```dart
await gromore.disposeAd(interstitialId);
```

## Banner、Feed 与 Draw 示例

这三种广告使用 Android `PlatformView` / iOS `UiKitView`。每个 Widget 需要一个由 Flutter 生成的稳定 `requestId`；不要在 `build()` 内反复生成。

为保证 Android/iOS 行为一致，请在 GroMore 控制台把这三类广告位配置为“模板渲染”。iOS 若混出自渲染 Banner、任一平台若为自渲染 Feed/Draw，插件会发送失败事件并释放素材，不会静默展示空白或拼接不完整的合规 UI。

### Banner

```dart
late final String bannerId =
    gromore.createViewRequestId(GromoreAdType.banner);

GromoreBannerView(
  requestId: bannerId,
  request: const GromoreBannerRequest(
    slotId: String.fromEnvironment('GROMORE_BANNER_SLOT_ID'),
    width: 320,
    height: 50,
  ),
)
```

### 模板信息流

```dart
late final String feedId =
    gromore.createViewRequestId(GromoreAdType.feed);

GromoreFeedView(
  requestId: feedId,
  request: const GromoreFeedRequest(
    slotId: String.fromEnvironment('GROMORE_FEED_SLOT_ID'),
    width: 360,
    height: 300,
    muted: true,
  ),
)
```

### 模板 Draw

```dart
late final String drawId =
    gromore.createViewRequestId(GromoreAdType.drawFeed);

GromoreDrawFeedView(
  requestId: drawId,
  request: const GromoreDrawFeedRequest(
    slotId: String.fromEnvironment('GROMORE_DRAW_SLOT_ID'),
    width: 360,
    height: 640,
    muted: true,
  ),
)
```

自渲染广告必须在原生侧完整实现广告标识、下载合规信息、投诉入口与点击区域注册，无法安全地用通用 Dart Widget 代替。

## 事件处理

```dart
final subscription = gromore.events.listen((GromoreAdEvent event) {
  if (event.requestId != rewardedId) return;

  switch (event.type) {
    case GromoreAdEventType.loaded:
      unawaited(gromore.showRewarded(rewardedId));
      break;
    case GromoreAdEventType.rewardEarned:
      // 仅在这里处理客户端奖励；生产环境优先使用 SSV。
      break;
    case GromoreAdEventType.failed:
    case GromoreAdEventType.showFailed:
      // event.code / event.message
      break;
    default:
      break;
  }
});
```

展示后的 `shown` 事件可能包含 `ecpm`（单位：分）、`adnName`、`adnSlotId` 和 `networkRequestId`。事件以 `requestId` 区分并发请求。PlatformView 销毁时会自动释放其原生广告对象。

## 广告预加载

插件使用 GroMore 官方“首次预缓存”能力，支持开屏、激励视频、插全屏和 Feed。Banner 与 Draw 不在官方支持范围内，因此 Dart API 不提供这两类预加载入口。调用前还需要在 GroMore 控制台为相应广告位开启预缓存开关。

把请求对象定义为共享常量，并在预加载和后续正常加载中复用；GroMore 要求后续请求参数与预缓存参数完全一致，才能命中缓存：

```dart
const rewardedRequest = GromoreRewardedRequest(
  slotId: String.fromEnvironment('GROMORE_REWARDED_SLOT_ID'),
  userId: 'flutter-user-id',
  customData: '{"source":"practice"}',
  rewardName: '能量',
  rewardAmount: 1,
);
const feedRequest = GromoreFeedRequest(
  slotId: String.fromEnvironment('GROMORE_FEED_SLOT_ID'),
  width: 360,
  height: 300,
  muted: true,
);

final GromorePreloadResult preloadResult = await gromore.preloadAds(
  const GromorePreloadConfig(
    // 默认 wifiOnly；改为 any 后 WiFi、蜂窝等可用网络均可提交。
    network: GromorePreloadNetwork.wifiOnly,
    interval: Duration(seconds: 2),
    concurrent: 2,
    items: <GromorePreloadItem>[
      GromorePreloadItem.rewarded(rewardedRequest),
      GromorePreloadItem.feed(feedRequest),
    ],
  ),
);

if (preloadResult == GromorePreloadResult.requested) {
  // requested 仅表示已交给原生 SDK，不代表素材已全部缓存成功。
  final String rewardedId = await gromore.loadRewarded(rewardedRequest);
}
```

约束与语义：

- 一次可提交 1～20 个不同广告位，`concurrent` 范围 1～20，`interval` 只能是 1～10 秒的整数秒。
- `wifiOnly` 在离线时返回 `skippedNoNetwork`，在蜂窝等非 WiFi 网络返回 `skippedNotWifi`；`any` 仅在无可用网络时跳过。iOS 的 `NWPathMonitor` 判断的是系统是否存在可用 route，不保证已穿过 captive portal；VPN 等虚拟接口下的 `wifiOnly` 判断也会偏保守。
- 网络判断是调用时的一次性门控。跳过的请求不会排队或自动重试，网络变化后应由 Flutter 再次调用。
- 原生预缓存接口没有完成回调、取消或清空能力；`disposeAd()` 只管理后续正常加载得到的广告对象。
- 建议在计划展示前预加载并尽量在一小时内使用，避免冷启动过早或大量预载降低实际展示率。开屏请求自身的 `GromoreSplashRequest.preload` 是 Android `setSplashPreLoad` 参数，与这里的批量首次预缓存不是同一能力。

实现依据见穿山甲 [GroMore 预缓存说明](https://www.csjplatform.com/supportcenter/28655) 与 [预缓存常见问题](https://www.csjplatform.com/supportcenter/28693)。

## 微信小程序/小游戏广告点击跳转

该能力是广告点击后的落地页跳转，不是 App 主动指定小程序 ID、路径或拉起微信。插件两端源码都不调用 `WXApi`，普通 GroMore 广告不需要微信 OpenSDK，因此插件不再捆绑 OpenSDK，也不替 Android 宿主声明微信包可见性。只有实际启用微信小程序/小游戏落地页时，才应由宿主按穿山甲和微信文档选择兼容 OpenSDK 并补齐平台配置。广告加载、展示 API 无需变化，点击仍通过现有 `GromoreAdEventType.clicked` 上报。该事件只表示广告点击回调，不代表微信已拉起、小程序/小游戏已打开或转化成功；官方没有提供这些客户端成功回调。目标小程序/小游戏由广告素材决定，后续跳转由穿山甲 SDK 处理。

接入时必须完成平台侧配置：

1. 在微信开放平台创建“移动应用”，登记与正式安装包一致的 Android 包名/签名及 iOS Bundle ID。
2. 在穿山甲应用配置中关联微信 AppID。Android 渠道包包名不同的，需要分别创建并关联对应移动应用。
3. iOS 还需在微信开放平台和穿山甲后台填写同一个 Universal Link，并在 Xcode `Signing & Capabilities` 中加入对应的 `Associated Domains`：`applinks:你的域名`。Universal Link 必须使用 HTTPS 且不带 query；域名服务器必须正确提供 AASA 文件，应用对应的 path 需用通配符覆盖子路径，例如 `/app/*`。
4. iOS 宿主 `Info.plist` 合并以下系统路由配置；不要覆盖应用已有的 URL Types 或查询白名单：

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>你的微信AppID</string>
    </array>
  </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>weixin</string>
  <string>weixinULAPI</string>
  <string>weixinURLParamsAPI</string>
</array>
```

Android 若实际启用该落地页能力，还需由宿主依照官方兼容矩阵引入 `com.tencent.mm.opensdk:wechat-sdk-android`，并在宿主 Manifest 的 `<queries>` 中声明 `com.tencent.mm`；普通广告无需这些配置。iOS 若确需 OpenSDK，也应由宿主或现有微信业务插件统一管理依赖。

iOS 15/Xcode 13 及以上会限制可查询 Scheme 的有效范围，请确保上面三个微信 Scheme 位于 `LSApplicationQueriesSchemes` 前 50 项。完整系统要求见[微信 iOS 接入指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)。

微信 AppID、Universal Link、包签名和 Associated Domains 属于微信开放平台、系统签名及 URL 路由配置，无法在 Flutter runtime 安全生效，因此没有重复放入 `GromoreConfig`。广告位 ID、预加载网络策略及其他运行期广告参数仍全部由 Flutter 传入。若宿主已经使用微信登录/分享插件，应继续由原插件管理 `WXEntryActivity`、`WXApiDelegate` 和 AppDelegate 回调，`stormy_gromore` 不会重复注册或抢占回调。

若宿主为该落地页能力或登录、分享等业务引入微信 OpenSDK，必须统一版本：Android 不要同时保留旧 `wechat-sdk-android-without-mta` 和 `wechat-sdk-android`，否则可能产生 duplicate classes；iOS 不要同时链接 `WechatOpenSDK` 静态库、`WechatOpenSDK-XCFramework` 或手工 framework。

接入依据见穿山甲 [Android 微信小程序/小游戏跳转接入](https://www.csjplatform.com/supportcenter/26769) 与 [iOS 微信小程序/小游戏跳转接入](https://www.csjplatform.com/supportcenter/26768)。最终必须使用已开通对应预算的真实广告位、正式签名包、已安装微信的 Android/iOS 真机验证；同时在实际接入微信 OpenSDK 时按其[个人信息处理规则](https://support.weixin.qq.com/cgi-bin/mmsupportacctnodeweb-bin/pages/RYiYJkLOrQwu0nb8)更新宿主隐私披露。移除未使用的 iOS `WechatOpenSDK-XCFramework` 后，插件不再因该 Pod 排除 simulator arm64；宿主自行引入的其他 Pod 仍需分别检查架构支持。

## Android 宿主配置

插件自身只依赖 GroMore 核心 SDK。请在宿主工程的仓库列表加入：

```gradle
maven { url 'https://artifact.bytedance.com/repository/pangle' }
```

插件使用 `compileSdk 36`、Java 17、`minSdk 24`。再按 GroMore 控制台真实启用的 ADN 添加 adapter 与严格匹配的 SDK。以下为迁入时保留的版本示例，并非本 workspace 的默认依赖；启用前需按所选核心 SDK 的兼容矩阵核对：

```gradle
implementation 'com.pangle.cn:mediation-gdt-adapter:4.680.1550.1'
implementation 'com.pangle.cn:mediation-baidu-adapter:9.4503.1'
implementation 'com.pangle.cn:mediation-ks-adapter:5.3.20.1.1'
implementation 'com.pangle.cn:mediation-sigmob-adapter:4.25.14.1'

// 仅 debug 包可用，禁止进入线上包。
debugImplementation 'com.pangle.cn:mediation-test-tools:7.7.1.6'
```

这些 adapter 不会传递实际 ADN SDK。将控制台下载的以下精确版本 AAR 放进宿主 `android/app/libs` 并用 `implementation fileTree(...)` 引入：

```text
GDTSDK.unionNormal.4.680.1550.aar
Baidu_MobAds_SDK_v9.4503.aar
kssdk-ad-5.3.20.1.aar
windAd-4.25.14.aar
windAd-common-2.0.1.aar
```

不要复制旧 `flutter_gromore` 自带的 6.x AAR。当前核心要求 `minSdk 24`，7.4+ GroMore 实际以 `arm64-v8a` 真机验证为准。插件自身的 Manifest 不主动声明定位、存储、电话或 `QUERY_ALL_PACKAGES` 等敏感权限，但 SDK/ADN AAR 可能通过 Manifest merge 带入权限。发布前必须检查 `merged_manifest` ；真实业务不需要的权限可在宿主 Manifest 中用 `tools:node="remove"` 显式移除，不能只依赖 Flutter 隐私开关。

若宿主已设置 `application@android:label`，GroMore AAR 的 Manifest 可能触发 label 合并冲突。此时在宿主 Manifest 根节点声明 `xmlns:tools="http://schemas.android.com/tools"`，并在 `<application>` 上增加 `tools:replace="android:label"`。

## iOS 宿主配置

插件只锁定 mediation core，不捆绑 iOS 微信 OpenSDK；实际启用的 ADN 及宿主业务需要的其他 SDK 由宿主 `ios/Podfile` 精确引入。以下同为迁入时保留的可选版本示例，使用前需核对兼容矩阵：

```ruby
pod 'GMGdtAdapter-Beta', '4.15.90.1'
pod 'GMBaiduAdapter-Beta', '10.050.3'
pod 'GMKsAdapter-Beta', '5.5.10.1.1'
pod 'GMSigmobAdapter-Beta', '5.1.2.1'

pod 'GDTMobSDK', '4.15.90'
pod 'BaiduMobAdSDK', '10.050'
pod 'KSAdSDK', '5.5.10.1'
pod 'SigmobAd-iOS', '5.1.2'
```

要求 iOS 13+、Xcode 15.2+。若请求 ATT，宿主 `Info.plist` 必须提供符合自身用途的 `NSUserTrackingUsageDescription`。同时按 GroMore 与已启用 ADN 的最新文档维护 SKAdNetwork IDs，并检查/合并 SDK bundle 中的 `PrivacyInfo.xcprivacy`。插件不会擅自修改宿主的 ATS、权限文案或 Privacy Manifest。

## 已知边界

- 第三方 ADN adapter/SDK 由宿主按 GroMore 控制台配置选择，插件不会强制打包所有广告联盟。
- 真正的填充、展示、点击、奖励回调与 eCPM 只能用已配置广告位在 Android/iOS 真机验证。
- iOS/Android 的部分请求选项为平台专属；插件保持统一 Dart 模型，但只在 SDK 提供对应能力的平台生效。例如 `isPaidApp` 仅 Android 生效；`forbidCaid` 在 iOS 映射到 `configuration.mediation.forbiddenCAID`。
