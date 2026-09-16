# Stormy 项目结构与各包使用指南

本指南按当前源码说明九个包的职责、接入顺序和使用逻辑。根目录是依赖工作区，不是可直接运行的 Flutter App；应用位于各包的 `example/` 或业务宿主工程。

## 1. 结构与依赖关系

```text
packages/
├── stormy_core/             # 网络、存储、日志、预加载
├── stormy_platform/         # 设备、图片、文件、原生权限
├── stormy_ui/               # App、主题、Widgets、权限提示
├── stormy_kit/              # 配置编排与兼容入口
├── stormy_i18n/             # 运行期语言状态
├── stormy_i18n_generator/   # 开发期 CLI、解析与生成
├── stormy_store_pay/        # App Store / Google Play
├── stormy_china_pay/        # 微信 / 支付宝
└── stormy_gromore/          # Android/iOS 广告桥接
```

各包公开入口为 `lib/<包名>.dart`，测试位于各自 `test/`。

| 包 | 仓库内直接依赖 | 应用中的职责 | 示例与详细说明 |
| --- | --- | --- | --- |
| `stormy_core` | 无 | 网络、存储、预加载 | [说明](../packages/stormy_core/README.md) |
| `stormy_platform` | core | 设备、图片、原生操作 | [说明](../packages/stormy_platform/README.md) |
| `stormy_ui` | core/platform/i18n | App、主题、Widgets | [说明](../packages/stormy_ui/README.md) |
| `stormy_i18n_generator` | 无 | 开发期生成器 | [说明](../packages/stormy_i18n_generator/README.md) |
| `stormy_kit` | core/platform/ui/i18n | 应用初始化、网络、存储、路由、主题、弹窗、刷新 | [示例](../packages/stormy_kit/example/lib/main.dart)、[模块指南](../packages/stormy_kit/STORMY_KIT_GUIDE.md) |
| `stormy_i18n` | 无 | 运行期语言状态 | [说明](../packages/stormy_i18n/README_zh.md)、[示例](../packages/stormy_i18n/example/lib/main.dart) |
| `stormy_store_pay` | 无 | 内购商品查询、购买、恢复与后端验单 | [说明](../packages/stormy_store_pay/README.md)、[示例](../packages/stormy_store_pay/example/lib/store_pay_page.dart) |
| `stormy_china_pay` | core/platform | 微信/支付宝支付、签约、部分授权及微信分享 | [说明](../packages/stormy_china_pay/README.md)、[统一入口](../packages/stormy_china_pay/lib/pay_manager.dart) |
| `stormy_gromore` | 无 | Android/iOS 聚合广告加载、展示、事件与预缓存 | [说明](../packages/stormy_gromore/README.md)、[示例接入](../packages/stormy_gromore/example/README.md) |

`stormy_kit` 不会自动引入支付或广告包。广告与内购也不依赖彼此；业务宿主按功能选择。`stormy_kit`、`stormy_i18n`、`stormy_store_pay` 有完整示例平台工程；`stormy_gromore/example/` 只有 Dart 示例，需要另建宿主；`stormy_china_pay` 尚无独立示例 App。

## 2. 开发与接入

### 工作区初始化

根配置要求 Dart `>=3.13.0 <4.0.0`。安装 FVM 后，在仓库根目录执行：

```sh
fvm install
fvm flutter pub get
fvm dart run melos bootstrap
fvm dart run melos list --long
```

根 `pubspec.yaml` 已注册九个包。新增 workspace 成员需加入 `workspace` 列表并声明 `resolution: workspace`；工作区内引用兄弟包可用 `stormy_gromore: any`，Pub 会解析为本地成员。已有示例保持独立依赖配置，不必改成 workspace 成员。

### 业务 App 添加依赖

例如 App 与 `stormy/` 仓库同级，在 App 的 `pubspec.yaml` 中按需添加：

```yaml
dependencies:
  stormy_kit:
    path: ../stormy/packages/stormy_kit
  stormy_i18n:
    path: ../stormy/packages/stormy_i18n
  stormy_store_pay:
    path: ../stormy/packages/stormy_store_pay
  stormy_china_pay:
    path: ../stormy/packages/stormy_china_pay
  stormy_gromore:
    path: ../stormy/packages/stormy_gromore
```

路径相对于 App 的 `pubspec.yaml`。只保留需要的条目；运行期依赖 `stormy_i18n`；生成器 `stormy_i18n_generator` 放入宿主 dev_dependencies。按需接入 core/platform/UI，见 [迁移说明](MIGRATION.md)。现有包并非全部发布到 pub.dev，不能假定同名线上版本等同于本仓库。安装依赖后使用 `package:<包名>/<包名>.dart` 导入。

示例 App 可在其目录执行 `fvm flutter pub get`、`fvm flutter run`。原生插件需要 Android/iOS 宿主配置和设备，桌面或 Web 不能验证支付与广告功能。

### 应用启动顺序

1. 初始化 Flutter binding，准备必要的网络和本地存储配置。
2. 配置并应用 `stormy_kit`，再由存储恢复语言偏好，挂载路由和 UI。
3. 用户完成宿主隐私流程后，按需初始化广告和第三方支付 SDK。
4. 内购先建立业务事件订阅，再初始化并注入真实后端验单函数。
5. 页面按需请求数据、商品或广告；页面释放订阅、控制器及其持有的广告资源。

`stormy().sdk(name, config)` 当前只保存配置，不会自动初始化这些 SDK，必须显式调用对应包的初始化方法。

## 3. stormy_kit：基础框架

### 初始化与路由

`stormy()` 仅校验已配置模块；配置 i18n 时需要可用存储。网络客户端通过 `StormyConfigAccessor.networkClient` 获取；存储由 `StormyStorage.instance` 管理。

```dart
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await stormy()
      .network(StormyNetworkConfig(baseUrl: 'https://api.example.com'))
      .storage(StormyStorageConfig.defaultConfig())
      .build(apply: false);
  final applied = await config.apply();
  if (!applied.networkApplied || !applied.storageApplied) {
    throw StateError('基础模块初始化失败');
  }

  final router = GoRouter(
    navigatorKey: StormyDialog.navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Stormy')),
        ),
      ),
    ],
  );
  runApp(StormyApp(router: router, appModel: AppModel.defaults()));
}
```

将示例域名替换为业务 API。`apply()` 返回包含模块状态、原始异常和堆栈的报告；`isAllApplied` 仅检查已配置模块。`build()` 自动应用失败时抛出携带报告的 `StormyInitializationException`。

`StormyApp` 组合 ScreenUtil、AdaptiveTheme、语言监听和 SmartDialog。自定义普通 `MaterialApp` 时将 `StormyDialog.navigatorKey` 绑定到 `navigatorKey`；使用 Router 时绑定到 `GoRouter`。使用 Riverpod Provider 的应用还需在根部挂载 `ProviderScope`，`StormyApp` 不负责这一步。

### 网络流程

配置 `StormyNetworkConfig` → 获取客户端 → 配置 token/header → 请求 → 响应外层解析 → `DataParser<T>` 映射业务数据。

```dart
import 'package:stormy_kit/stormy_kit.dart';

Future<Map<String, dynamic>> loadProfile(String token) async {
  final client = StormyConfigAccessor.networkClient;
  if (client == null) throw StateError('网络未初始化');
  client.completeGlobalToken(token: token);
  return client.get<Map<String, dynamic>>(
    '/profile',
    requireToken: true,
    cancelTag: 'profile-page',
    parser: const DirectParser<Map<String, dynamic>>(),
  );
}
```

按后端协议配置 `ResponseParsingConfig` 的成功码及字段；`JsonParser(Model.fromJson)` 映射单对象，`JsonListParser(Model.fromJson)` 映射列表。错误通过 `ErrorHandler` 转换为网络异常，由调用方捕获。页面离开时可调用 `client.cancelByTag('profile-page')`；流式接口用 `requestStream()` 消费原始 `ResponseBody.stream`，并管理流订阅和取消。

### 存储流程

先在 `StormyStorageConfig.buckets` 声明分区，再调用 `bucket(name)`；列表也需要预注册独立分区。

```dart
import 'package:stormy_kit/stormy_kit.dart';

Future<String?> cacheGreeting() async {
  final storage = StormyStorage.instance;
  await storage.set('greeting', '你好', expiresIn: const Duration(hours: 1));
  return storage.get<String>('greeting');
}
```

KV 键参数为 `Object`，运行时仅接受 `String`、`int`；前缀只应用字符串，`0` 与 `"0"` 独立保存、枚举和删除。列表 ID 仍为字符串，已有 Hive 数据不迁移。

普通类型使用 `set/get` 或 `setString/getString`；JSON 使用 `setJson/getJson`；自定义对象注册 Hive adapter 或提供 decoder。读取已过期数据返回空值，批量回收可调用 `clearAllExpiredAcrossBuckets()`。`list<T>(name)` 提供 `add`、`put`、`getAll`、`query`；每条记录的 ID 和过期时间由列表管理。退出整个服务时调用 `close()`，不要在普通页面销毁时关闭全局存储。加密分区的密钥由宿主安全存储管理，不照搬示例中的测试密钥。

### UI、主题与刷新

| 功能 | 入口与使用方式 |
| --- | --- |
| 确认/自定义弹窗 | `StormyDialog.instance.showConfirm/showAlert/showCustom`；确认结果是 `bool?`，仅 `== true` 时执行确认操作 |
| Toast / Loading | 当前源码通过 `stormy_kit` 导出的 `SmartDialog.showToast/showLoading/dismiss` 提供；`StormyDialog` 当前没有这些同名包装方法 |
| 主题 | 构建时 `.theme(StormyThemeConfig(...))`；运行时 `StormyTheme.setLightMode/setDarkMode/setSystemMode(context)` |
| 刷新 | `.refresh(StormyRefreshConfig(...))` 设置配置；`EasyRefresh` 传入 `buildDefaultHeader()`、`buildDefaultFooter()`，或调用 `setRefresh()` 设置全局 builder |
| 列表分页 | `onRefresh` 重置页码，`onLoad` 请求下一页；手动控制时使用 `EasyRefreshController.finishRefresh/finishLoad`，页面销毁时释放 controller |
| 通用组件与工具 | `widgets/` 提供基础页面、按钮、输入等；`utils/` 包含格式化、权限、图片及任务预加载工具 |

`utils/preload` 是通用任务调度，与 GroMore 的广告首次预缓存是两个独立机制，详见 [任务预加载说明](../packages/stormy_core/lib/utils/preload/README.md)。

## 4. stormy_i18n：文案生成与语言状态

### 编译期流程

在业务 App 配置 `flutter_localizations` 和 `flutter: generate: true`，并在 dev_dependencies 添加 `stormy_i18n_generator`，然后执行：

```sh
fvm dart run stormy_i18n_generator init
fvm dart run stormy_i18n_generator gen
fvm dart run stormy_i18n_generator watch
```

`init` 用于首次创建配置和示例；已有项目修改文案后用 `gen`，开发时可选常驻 `watch`。`init --force` 会清除旧配置和生成目录，不作为日常命令。

生成链路：`stormy_i18n.yaml` 指定语言和目录 → `lib/l10n/src/*.dart` 定义 `I18nItem` → 生成 ARB → 调用 Flutter `gen-l10n` → 输出 `AppLocalizations` 和 `context.l10n` 扩展。

例如采用仓库示例的 `zh_CN`、`zh_TW`、`en_US` 配置时，在源文案目录编写：

```dart
import '../stormy_i18n.dart';

class LoginMessages {
  static const greeting = I18nItem(
    key: 'greeting',
    zh_CN: '你好，{name}',
    zh_TW: '你好，{name}',
    en_US: 'Hello, {name}',
    placeholders: {'name': I18nPlaceholder.string()},
  );
}
```

生成后在页面导入 `lib/l10n/stormy_i18n.dart`，使用 `context.l10n.greeting('用户')`。省略 `key` 时，生成器将类名和字段名组合为 snake_case key。新增语种要同步 `stormy_i18n.yaml`；不要手工修改生成的 ARB、`l10n.yaml` 和 `generator/` 文件。

### 运行期流程

与 `stormy_kit` 一起使用时，在构建器添加：

```dart
.i18n(StormyI18nConfig(
  storageKey: 'app_locale',
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
))
```

这段为链式配置片段，`AppLocalizations` 来自生成文件。存储先初始化，语言随后读取缓存；`StormyApp` 监听语言变化。切换调用 `await StormyI18n.changeLocale(const Locale('en', 'US'))`；传入 `null` 清除偏好。

独立使用时调用 `StormyI18n.init(localeResolver: ..., onSave: ...)`，由宿主实现读取和保存，并用 `ValueListenableBuilder` 将 `localeNotifier` 绑定到 `MaterialApp.locale`。初始化的优先级为缓存 → `defaultLocale` → 当时的系统语言；当前实现启动时会取系统语言快照，`changeLocale(null)` 才将 notifier 设为 `null`，不要把它误认为始终自动订阅系统语言变化。

## 5. stormy_store_pay：内购与验单

### 接入前提与初始化

在 App Store Connect / Google Play Console 配好商品与测试账号，完成宿主应用的商店配置。管理器只选择 Android Google Play 或 iOS Apple 实现，其他平台初始化返回 `false`。

```dart
import 'package:stormy_store_pay/stormy_store_pay.dart';

Future<List<StoreProductInfo>> prepareStore(
  PurchaseVerifier verifyOnServer,
) async {
  final store = StorePayManager.instance;
  final ready = await store.initialize(
    config: const StorePayConfig(consumableProductIds: {'coins_100'}),
    verifier: verifyOnServer,
  );
  if (!ready) throw StateError('内购不可用或初始化失败');
  return store.queryProducts(['coins_100', 'premium_monthly']);
}
```

商品 ID 替换为控制台配置。`verifyOnServer` 的签名是 `Future<bool> Function(PurchaseDetails)`，必须调用业务后端核验交易/收据/token，并在后端幂等记录订单；不能用固定 `true` 替代。未配置 verifier 时初始化直接失败。

### 购买与恢复流程

1. 在初始化前订阅 `purchaseSuccessStream`、`purchaseErrorStream`、`purchaseRestoredStream`，初始化成功后开放购买按钮。同一实例的流和 notifier 从创建到销毁保持稳定。
2. `queryProducts()` 返回统一的 `StoreProductInfo`；展示本地化价格与商品信息，用 `nativeProductId` 关联商店商品，用统一 ID 调用 `getProduct()`。
3. `purchaseProduct(product, offer: ..., applicationUserName: ...)` 发起购买；offer 必须来自该商品。返回 `true` 仅代表发起成功，权益不能据此发放。
4. 原生购买流返回状态后调用 verifier；验证通过才发布成功/恢复事件。业务以服务端订单与权益为准刷新 UI。
5. 用户取消会进入错误流，可根据 `purchaseStatus == PurchaseStatus.canceled` 区分；验单失败保留未完成交易，以便后续重试。
6. `restorePurchases()` 恢复非消耗品与订阅；也可在订阅就绪后使用 `queryProducts(..., autoRestorePurchases: true)`。消耗品余额从业务后端恢复。

默认 `autoCompletePurchases: true` 在成功验单后完成交易；若关闭，宿主必须在验单和交付成功后检查 `pendingCompletePurchase`，调用导出的 `InAppPurchase.instance.completePurchase(details)`。统一管理器目前没有同名便捷方法。

推荐 `purchaseAndWait(product)`：内部先订阅再发起，按 `nativeProductId` 匹配，拒绝同商品并发。失败、取消、超时和销毁均结束等待。低层 `waitForPurchase(nativeProductId)` 保留，使用时必须先创建等待再发起。`googleExtension` / `appleExtension` 仅在相应平台成功初始化后可用。

页面取消自己建立的 `StreamSubscription`；仅在整个内购服务停止时调用 `StorePayManager.instance.dispose()`。启动恢复事件可能在初始化期间发生，业务权益应主动从后端同步，不能只靠页面流事件推导。

## 6. stormy_china_pay：微信与支付宝

### 配置与平台准备

业务宿主负责微信 AppID、签名、URL Scheme、Universal Link/Associated Domains，以及支付宝回调配置。不要使用包内的 `defaultConfig()` 作为业务配置。

```dart
import 'package:stormy_china_pay/stormy_china_pay.dart';

Future<void> initializeChinaPay() async {
  await StormyChinaPay().initAll(
    weChatConfig: WechatConfig(
      appId: const String.fromEnvironment('WECHAT_APP_ID'),
      universalLink: const String.fromEnvironment('WECHAT_UNIVERSAL_LINK'),
      miniProgramUsername: const String.fromEnvironment('WECHAT_MINI_PROGRAM'),
    ),
    alipayConfig: AlipayConfig(
      authAppId: const String.fromEnvironment('ALIPAY_APP_ID'),
      universalLink: const String.fromEnvironment('ALIPAY_UNIVERSAL_LINK'),
    ),
  );
}
```

若只接入一个渠道，直接调用 `initWeChat(config)` 或 `initAlipay(config)`。应用级初始化一次即可；重复初始化不增加监听，并发初始化共享结果；失败后可重试。

### 调用与事件逻辑

| 功能 | 调用路径 | 结果处理 |
| --- | --- | --- |
| 微信支付 | 后端创建签名订单 → `pay(type: SDKPaymentType.weChat, orderInfo: ..., weChatPayment: ...)` | `PayResult` 仅表示 SDK 请求结果；监听 `paymentStream` 后向后端确认订单 |
| 支付宝支付 | 后端返回签名订单串 → `pay(type: SDKPaymentType.alipay, orderInfo: ...)` | 处理调用返回及 `paymentStream`，后端支付通知为最终依据 |
| 微信签约 | `weChatSDK.signPay(username, path, orderInfo)` | 由小程序完成，回 App 后查询服务端签约状态 |
| 支付宝签约 | `pay(..., isAuth: true)` | 回前台的事件不证明签约完成，需后端确认；当前返回值也不能单独判断完成情况 |
| 图片分享 | `shareImage(XFile(...))` 或 `weChatSDK.shareImageUrl(...)` | 监听 `shareStream`；当前 `SharePlatform.qq` 分支返回 `false`，尚未实现 |
| 打开小程序 | `weChatSDK.openMiniProgram(path, username: ...)` | 需要真实原始 ID 和路径，必要时监听 `miniProgramStream` |
| 支付宝授权 | `alipaySDK.auth(orderInfo)` | `authStream` 仅用于 SDK 事件反馈，登录/授权有效性由后端确认 |

微信支付参数 `Payment` 由本包主入口导出，使用后端签名字段构造；不要把后端 JSON 直接传入 SDK。

`PayResult.status` 和支付事件使用 `launched`、`pending`、`platformSucceeded`、`cancelled`、`failed`。微信发起成功仅为 `launched`；支付宝签约回前台为 `pending`，应查询后端。`isSuccess` 仅对应平台明确成功，不等于服务端已发放权益。

在发起操作前订阅事件。`listenPaymentOnce/listenShareOnce/listenAuthOnce` 在收到第一个事件后取消订阅，但不按订单过滤、不自带超时；同平台未结束订单不允许并发覆盖，业务仍应按 `orderInfo` 等标识过滤。调用失败且没有事件时，也要取消一次性订阅，防止接到下一笔订单结果。

页面销毁取消页面订阅。`dispose()` 终止当前实例；旧实例再次使用会报错，重新获取默认入口会创建新对象。仅在停止整个服务时调用。

## 7. stormy_gromore：聚合广告

### 平台配置与初始化

本包从独立插件迁入，保留原生桥接、测试、示例和许可证；仅加入 workspace 并调整文档/包元数据。广告 SDK 不随基础框架启动。

| 平台 | 当前包配置 | 宿主责任 |
| --- | --- | --- |
| Android | GroMore `7.7.1.6`、`compileSdk 36`、`minSdk 24`、Java 17 | 配置 Pangle Maven 仓库及实际启用的 ADN adapter/SDK，处理 Manifest 合并 |
| iOS | `Ads-CN-Beta/CSJMediation-Only 7.8.0.3`、iOS 13+、CocoaPods | 配置启用的 ADN、ATT 用途文案、SKAdNetwork 与平台隐私文件 |

版本来自当前 `android/build.gradle` 与 podspec，不代表最新版。插件仅包含 mediation core，第三方广告联盟由宿主按控制台兼容矩阵补齐。原生配置详见 [插件说明](../packages/stormy_gromore/README.md#android-宿主配置)。

宿主完成用户隐私同意后调用以下函数；不要在插件注册或用户同意前初始化：

```dart
import 'package:stormy_gromore/stormy_gromore.dart';

Future<void> initializeAdsAfterConsent() async {
  final ads = StormyGromore.instance;
  final tracking = await ads.requestTrackingAuthorization();
  await ads.initialize(GromoreConfig(
    appIds: const GromoreAppIds(
      android: String.fromEnvironment('GROMORE_ANDROID_APP_ID'),
      ios: String.fromEnvironment('GROMORE_IOS_APP_ID'),
    ),
    appName: 'Stormy Demo',
    privacy: GromorePrivacyConfig(
      canUseIdfa: tracking == GromoreTrackingStatus.authorized,
    ),
  ));
}
```

iOS 请求 ATT 前须有 `NSUserTrackingUsageDescription`；Android 返回 `notSupported`。隐私配置默认关闭采集能力，只按宿主已获得的授权开启。使用单例，等待初始化完成后再创建广告；并发初始化会合并，失败后允许重试。

### 六类广告的使用顺序

先订阅 `ads.events` 并处理流错误，再发起请求；按 `requestId` 区分每次请求，使用 `event.adType` 和 `event.type` 路由。`load*` 返回 ID 只表示原生已接受请求，**不表示素材已加载完毕**。

| 类型 | 请求模型 | 调用顺序 |
| --- | --- | --- |
| 开屏 | `GromoreSplashRequest` | `loadSplash()`；默认 `autoShow: true`，手动模式等待 `loaded` 后 `showSplash(id)` |
| 激励 | `GromoreRewardedRequest` | `loadRewarded()` → `loaded` → `showRewarded(id)` → 奖励/关闭事件 |
| 插全屏 | `GromoreInterstitialRequest` | `loadInterstitial()` → `loaded` → `showInterstitial(id)` |
| Banner | `GromoreBannerRequest` | `createViewRequestId(GromoreAdType.banner)` → `GromoreBannerView` |
| Feed | `GromoreFeedRequest` | `createViewRequestId(GromoreAdType.feed)` → `GromoreFeedView` |
| Draw | `GromoreDrawFeedRequest` | `createViewRequestId(GromoreAdType.drawFeed)` → `GromoreDrawFeedView` |

视图广告需传入正数 `width/height`，广告位配置为模板渲染。`requestId` 在 State 初始化或用户开始一次新加载时生成，不在每次 `build()` 时重新生成。失败后移除旧 PlatformView，使用新 ID 重建。

### 事件与资源生命周期

- `loaded`：允许展示；`shown`：已展示，可包含 eCPM 及广告联盟信息。
- `failed/showFailed`：处理错误并解除页面等待状态；`show*` 的异常也需捕获。Android 返回 `activity_unavailable` 时可保留 ready 广告，回前台再展示。
- `rewardEarned`：奖励结果通过，可结合服务端 SSV 幂等发奖；`rewardFailed`：验证失败。播放完成和关闭均不等于获得奖励。
- 激励的 `closed` 可能早于奖励回调；保留 ID 与业务订阅直到奖励结果或约定等待期结束。原生保留期由 `rewardCallbackRetention` 控制，默认 6 秒，应长于业务等待期。
- `disposed`：原生对象已释放。未展示且不再需要的全屏广告调用 `disposeAd(id)`；PlatformView 从树中移除时释放其原生对象。关闭后的激励不要为了页面收尾立即释放，避免丢失延迟奖励。

示例页面演示 SDK 交互与状态显示，不实现业务钱包或服务端发奖。广告业务服务可持有跨页面奖励订阅，页面只管理自己的展示状态。

### 首次预缓存

初始化后调用 `preloadAds(GromorePreloadConfig(...))`，支持 Splash、Rewarded、Interstitial 和 Feed；Banner/Draw 不支持此入口。GroMore 控制台也需为对应广告位开启预缓存。

默认 `wifiOnly`，可选 `any`。`requested` 表示请求已提交，不代表缓存完成；`skippedNoNetwork/skippedNotWifi` 不会排队重试，网络恢复后由业务再次提交。后续正式加载应复用同一请求参数，否则可能无法命中缓存。每批 1–20 个不同广告位，并发 1–20，间隔为 1–10 整数秒。

## 8. 验证与常见问题

在对应包目录执行：

```sh
fvm flutter analyze
fvm flutter test --no-pub
```

广告包可独立检查 Dart API、测试及示例：

```sh
cd packages/stormy_gromore
fvm dart analyze lib test example/lib
fvm flutter test --no-pub
```

| 现象 | 排查路径 |
| --- | --- |
| 配置校验失败 | `stormy().build()` 默认需要 network 和 storage；检查 URL、分区和应用结果 |
| 弹窗找不到 Context | 为 GoRouter / MaterialApp 绑定 `StormyDialog.navigatorKey` |
| 文案不更新 | 从包含 `stormy_i18n.yaml` 的 App 目录执行 `gen`，检查语言列表和生成文件导入 |
| 内购初始化失败或无事件 | 检查 verifier、商店可用性、初始化结果；初始化前建立稳定流订阅，销毁后获取新实例 |
| 支付回调成功但权益未开通 | 服务端查询订单与验签；不要按客户端调用返回值直接开通权益 |
| 广告 `MissingPluginException` | 在 Android/iOS 宿主添加插件依赖后重新构建；hot reload 不会注册新原生插件 |
| 广告 load 返回后立即 show 失败 | 等待匹配 ID 的 `loaded` 事件，确认 Activity 在前台 |
| 广告未填充 | 检查平台 App ID、聚合广告位、模板类型、签名及 ADN 依赖配置 |

Dart 单元测试使用模拟通道，不能证明广告填充、支付成功或真实设备回调正确。发布前在目标平台真机完成展示、关闭、后台切换、延迟奖励、支付取消、验单与恢复购买验证。

### 本次集成验证（2026-09-16）

使用 `.fvmrc` 指定的 Flutter 3.47.1，在临时宿主中完成以下检查：

| 检查 | 结果 |
| --- | --- |
| Pub 依赖解析、`melos list --long` | 五个 workspace 包均可识别 |
| 五个包的 Dart 测试 | 61 项通过：kit 14、i18n 2、store_pay 24、china_pay 3、gromore 18 |
| GroMore Android 原生测试 | `:stormy_gromore:testDebugUnitTest`，4 项通过 |
| GroMore Dart 静态分析 | 无 error/warning，原代码保留 2 条 `prefer_initializing_formals` 信息提示 |
| 本文完整 Dart 示例 | 6 段通过静态分析；另有文案与链式配置片段按生成 API 核对 |
| Android arm64 debug APK | 构建成功 |
| iOS debug、禁用签名 | 构建成功，输出 `Runner.app` |

原生构建仍提示后续 Flutter 版本需要迁移 Android Built-in Kotlin，以及为 iOS 增加 Swift Package Manager 支持；当前固定版本可通过现有 Kotlin Gradle Plugin / CocoaPods 配置构建。本次未运行真实广告位、商店交易或支付回调。
