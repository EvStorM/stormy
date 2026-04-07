# Stormy Kit 深度解析与使用指南

## 1. 库概览 (Overview)
**Stormy Kit** (`stormy_kit`) 是一个综合性的 Flutter 基础能力设施库。它的核心设计理念是**“统一下沉、链式配置、模块解耦”**。通过高度封装第三方优秀框架（如 `dio`, `hive_ce`, `easy_refresh`, `riverpod` 等），并在此基础上提供更加规整、易用且一致的 API 面板，极大降低了 Flutter 应用的基础设施搭建成本。

核心提供的能力模块包括：
- **统一配置中心 (`StormyConfig`)**：提供集中式构建应用核心参数。
- **网络模块 (`StormyNetwork`)**：基于 `Dio` 的强力封装，集成解析器和开箱即用的超时、Token 配置。
- **持久化存储模块 (`StormyStorage`)**：基于 `hive_ce`，支持时效性控制（过期清除）、多 Box 隔离和完善的列表操作（分页）。
- **全局弹窗处理 (`StormyDialog`)**：支持无 `BuildContext` 依赖全局调用弹窗及 Toast。
- **下拉刷新 (`StormyRefresh`)**：深度集成 `easy_refresh` 并关联应用的全局主题及国际化。

## 2. 初始化与配置 (Initialization)

推荐在应用程序启动时 (`main.dart` -> `main()` 函数内) 进行全局化配置。框架提供了优雅的链式构建器模式，并能在最后一次性完成校验。

```dart
import 'package:stormy_kit/stormy_kit.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 链式初始化
  await stormy()
      .network(StormyNetworkConfig(
        baseUrl: 'https://api.yourdomain.com',
        connectTimeout: const Duration(seconds: 15),
        enableLogging: true,  // 自动接入日志拦截器
      ))
      .storage(StormyStorageConfig.defaultConfig(
        boxName: 'app_main_box', // 默认存储域
      ))
      .dialog(StormyDialogConfig.defaultConfig().copyWith(
        confirmText: '确定',
        cancelText: '取消',
        backgroundColor: Colors.white,
      ))
      .build(); // 将执行验证与应用

  // 2. 初始化刷新组件默认样式
  await setRefresh();

  runApp(const MyApp());
}
```

> [!NOTE]
> 在执行 `runApp` 前，请务必确保 `build()` 已经完成，这会同步完成 Box 注册与网络拦截器的装载配置。

---

## 3. 各模块详细使用指南

### 3.1 🌐 网络模块 (StormyNetwork)
所有的网络请求都由单例入口掌控，简化常用的增删改查场景。

**发起基础请求：**
```dart
// GET请求 (支持 query 参数拼接)
final data = await StormyNetwork.instance.get(
  '/api/user/info',
  query: {'id': 1},
);

// POST请求
final response = await StormyNetwork.instance.post(
  '/api/user/update',
  data: {'name': '张三', 'age': 20},
);
```

**解析器 (Parser) 增强响应类型安全：**
可以通过传入 `parser` 函数，在获取到网络 raw 数据的第一时间立刻反序列化为模型对象：
```dart
final userList = await StormyNetwork.instance.get<List<User>>(
  '/api/users',
  parser: (data) => (data as List).map((e) => User.fromJson(e)).toList(),
);
```

**认证体系快速接管：**
```dart
// 登录成功后写入 Token (将自动注入到 Header：'Authorization: Bearer <token>')
StormyNetwork.instance.setAuthToken('ey...');

// 登出时清除
StormyNetwork.instance.clearAuthToken();
```

---

### 3.2 💾 存储模块 (StormyStorage)
不仅仅是 Key-Value，Stormy 扩展了**带过期时间的缓存机制**以及**高度特化的列表分页 API**。

**基础存取（自带安全类型转换）：**
```dart
final storage = StormyStorage.instance;

await storage.setString('username', 'Stormy');
await storage.setBool('is_first_launch', false);

// 取值
String? username = storage.getString('username');
bool? isFirstLauch = storage.getBool('is_first_launch');
```

**时效性控制 (Expiry Cache):**
适用于首页数据、弱一致性数据缓存方案。自带过期淘汰机制，如果读取时已过期，则返回 null 并自动清理：
```dart
// 保存并声明数据在 2 小时后失效
await storage.setJsonWithExpiry(
  'home_feed',
  {'items': []},
  const Duration(hours: 2),
);

// 获取过期数据（若过期返回null）
final feed = storage.getJson('home_feed');
```

**列表增删与分页 API (List Storage):**
特别优化了对于 List 型数据的持久化存储，并且自带长度缓存与分页截取。
```dart
// 增删
await storage.appendToList<String>('search_history', 'Flutter');
await storage.removeFromList<String>('search_history', 0); // 从指定索引移除

// 分页查询获取
final pageInfo = storage.getListPageInfo('search_history', pageSize: 10);
// pageInfo.hasNextPage (是否有下一页)
// pageInfo.totalCount  (总条数)

final items = storage.getListPage<String>(
  'search_history', 
  page: 1, 
  pageSize: 10,
);
```

---

### 3.3 💬 弹窗模块 (StormyDialog)
全局弹窗脱离生命周期绑架。内部依托于 `NavigatorState` 全局绑定键实现**无 Context 调用**，这意味着你可以在任意的异步方法（例如 `Dio` 拦截器报错处理）中弹出对话框。

```dart
// 1. Toast 黑条轻提示
StormyDialog.instance.showToast('登录成功', type: ToastType.success);

// 2. Alert 普通警告
await StormyDialog.instance.showAlert(
  title: '提示',
  message: '由于网络波动，您的操作未保存',
);

// 3. Confirm 确认抉择（返回 bool 结果阻断异步代码流）
bool? isConfirmed = await StormyDialog.instance.showConfirm(
  title: '警告',
  message: '确认删除该账号吗？此操作不可逆。',
  isDestructive: true, // true 会使确认按钮变为红色警告样式（如 iOS 的 DestructiveAction）
);
if (isConfirmed == true) {
  // 执行删除逻辑
}

// 4. 全局浮层 Loading
StormyDialog.instance.showLoading(message: '加载中...');
// ...执行耗时任务...
StormyDialog.instance.hideLoading();
```

> [!IMPORTANT]
> **必需配置：** 为了保证 `StormyDialog` 能够正确在顶层绘制 UI 节点，请务必在底层的 `MaterialApp` （或 `CupertinoApp` / `GoRouter`） 中绑定 `navigatorKey` 给它。
> ```dart
> MaterialApp(
>   navigatorKey: StormyDialog.navigatorKey, // 极其重要
>   home: const HomePage(),
> );
> ```

---

### 3.4 🔄 刷新模块 (StormyRefresh)
统一封装了 `EasyRefresh`，使用 `setRefresh()` 初始化后，你的滚动组件会自动读取当前 App 的主基绿色并应用到加载圆圈，同时将“下拉刷新...”、“释放加载...”等文案同步为国际化词汇。业务侧完全无需再封装。

## 4. 架构优势总结
**极致的统一性导出**：`stormy_kit` 暴露的单一引入机制：
```dart
import 'package:stormy_kit/stormy_kit.dart';
```
所有下游业务包或项目主工程只需要引入 `stormy_kit` ，即能直接使用框架封装的模块以及原生的 `Dio`, `GoRouter`, `Riverpod`, `ScreenUtil` 等库的核心 API，减少了大量 Pub 包的版本维护成本。
