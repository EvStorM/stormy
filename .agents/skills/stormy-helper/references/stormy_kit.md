# Stormy Kit (`stormy_kit`) 初始化与统一导出指南

`stormy_kit` 是 stormy monorepo 中的核心基础设施包，负责管理应用的全局配置初始化、第三方基础库的统一下沉与导出。

---

## 1. 统一链式配置初始化 (`StormyConfig`)

推荐在应用启动时（`main.dart` -> `main()` 函数内）通过单例链式调用完成各模块配置。这能确保在 Widget 渲染前完成 Box 注册与网络拦截器的装载。

### 核心初始化示例

```dart
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 链式配置与构建
  await stormy()
      .network(StormyNetworkConfig(
        baseUrl: 'https://api.yourdomain.com',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        enableLogging: true, // 自动绑定 Talker 日志拦截器
      ))
      .storage(StormyStorageConfig.defaultConfig(
        boxName: 'app_main_box', // 默认存储域
      ))
      .dialog(StormyDialogConfig.defaultConfig().copyWith(
        confirmText: '确定',
        cancelText: '取消',
        backgroundColor: Colors.white,
      ))
      .build(); // 同步加载全局配置依赖，在 Widget 构建前完成

  // 2. 初始化下拉刷新组件全局主题与语言
  await setRefresh();

  runApp(const MyApp());
}
```

> [!CAUTION]
> **必须在 `runApp()` 之前 `await stormy()....build()`**。
> `build()` 会异步初始化 Hive 存储、注册单例与装载 Dio 网络拦截器。如果不进行 `await`，在 Widget 初始化生命周期里直接读取 `StormyStorage` 或发送网络请求会导致依赖未注册异常崩溃。

---

## 2. 统一下沉与第三方包导出

为了防止不同业务子包对第三方库的版本冲突及维护混乱，`stormy_kit` 采用 **“下沉统一导出”** 策略。业务子包只需在 `pubspec.yaml` 引入 `stormy_kit`：

```yaml
dependencies:
  stormy_kit:
    path: ../../packages/stormy_kit
```

即可直接使用以下被 `stormy_kit` 间接导出的核心包，**严禁**在业务子包中直接添加这些包的依赖：

*   **状态管理**：`hooks_riverpod` (Riverpod 2.x), `flutter_hooks`
*   **网络与日志**：`dio`, `talker` (Talker 日志拦截器)
*   **路由**：`go_router`
*   **持久化**：`hive_ce`, `hive_ce_flutter` (Hive 社区版)
*   **屏幕适配**：`flutter_screenutil`
*   **弹窗**：`flutter_smart_dialog`
*   **下拉刷新**：`easy_refresh`
*   **工具与多媒体**：`url_launcher`, `uuid`, `image_picker`, `gal` (保存图片至相册), `permission_handler`
*   **多语言**：`stormy_i18n`

---

## 3. 细分功能子指南

为了使开发者在使用特定基础设施时能够聚焦具体的 API 细节，请根据当前开发任务查阅对应的细分子指南：

*   🌐 **网络请求、Dio 配置、Token 认证与响应解析**：
    👉 查阅 [references/stormy_kit_network.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_network.md)
*   💾 **本地存储、过期 (TTL) 缓存、隔离 Box 与分页列表**：
    👉 查阅 [references/stormy_kit_storage.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_storage.md)
*   💬 **无 Context 弹窗、全局 Toast、Confirm 面板与 Loading HUD**：
    👉 查阅 [references/stormy_kit_dialog.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_dialog.md)
*   🔄 **下拉刷新与全局品牌风格及国际化样式绑定**：
    👉 查阅 [references/stormy_kit_refresh.md](file:///Volumes/Evils/Documents/github/stormy/.agents/skills/stormy-helper/references/stormy_kit_refresh.md)
