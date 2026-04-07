# Stormy Framework

Stormy 是一个 Flutter 开发框架，提供统一的网络请求、本地存储、对话框管理、刷新等功能。

## 功能特性

- **网络模块** - 统一的网络请求客户端 (Dio)
- **存储模块** - 本地数据存储服务 (Hive)
- **对话框模块** - 统一对话框管理
- **刷新模块** - 下拉刷新和上拉加载
- **配置模块** - 应用配置管理
- **国际化模块** - 多语言配置与支持 (Stormy I18n)
- **组件库** - 通用 UI 组件
- **工具库** - 常用工具函数
- **SDK 集成** - 第三方 SDK 集成

## 目录结构

```
lib/
├── stormy.dart           # 统一导出文件
├── core/
│   ├── network/         # 网络模块
│   ├── dialog/          # 对话框模块
│   ├── storage/         # 存储模块
│   ├── refresh/         # 刷新模块
│   └── config/          # 配置模块
├── widgets/             # 通用组件
├── utils/               # 工具类
├── sdk/                 # SDK 集成
└── modules/             # 模块管理
```

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 初始化框架

```dart
import 'package:stormy/stormy.dart';

void main() async {
  // 初始化存储服务
  await StormyStorageService.instance.initialize();
  
  // 初始化配置
  StormyAppConfig.instance.initialize(
    config: {
      'apiBaseUrl': 'https://api.example.com',
      'isDebugMode': true,
    },
  );
  
  runApp(MyApp());
}
```

### 3. 使用网络模块

```dart
// GET 请求
final response = await StormyConfigAccessor.networkClient!.get('/api/users');

// POST 请求
final response = await StormyConfigAccessor.networkClient!.post(
  '/api/login',
  data: {'username': 'xxx', 'password': 'xxx'},
);
```

### 4. 使用存储模块

```dart
// 保存数据
await StormyStorageService.instance.setString('token', 'xxx');
await StormyStorageService.instance.setInt('userId', 123);
await StormyStorageService.instance.setBool('isLogin', true);
await StormyStorageService.instance.setJson('userInfo', {'name': 'xxx'});

// 读取数据
final token = StormyStorageService.instance.getString('token');
final userId = StormyStorageService.instance.getInt('userId');
final isLogin = StormyStorageService.instance.getBool('isLogin');
final userInfo = StormyStorageService.instance.getJson('userInfo');
```

### 5. 使用对话框模块

```dart
// 确认对话框
final result = await StormyDialogManager.instance.showConfirmDialog(
  context: context,
  title: '确认删除',
  content: '确定要删除这个项目吗？',
  confirmText: '删除',
  isDestructive: true,
);

// Toast 消息
StormyDialogManager.instance.showToast(context, '操作成功');
```

### 6. 使用刷新模块

```dart
final controller = StormyRefreshHelper.createRefreshController();

// 下拉刷新
await StormyRefreshHelper.onRefresh(controller, () async {
  await fetchData();
});

// 上拉加载
await StormyRefreshHelper.onLoadMore(controller, () async {
  await loadMoreData();
});
```

### 7. 国际化支持

通过 `stormy_i18n` 插件，框架提供了对多语言的完整支持：

```dart
import 'package:stormy_i18n/stormy_i18n.dart';

// 配置并初始化国际化模块
await stormy()
  .i18n(StormyI18nConfig(
    defaultLocale: const Locale('zh', 'CN'),
    storageKey: 'app_locale',
    supportedLocales: const [
      Locale('zh', 'CN'),
      Locale('en', 'US'),
    ],
    localizationsDelegates: [
      // 填入你的项目 delegates，例如：
      // AppLocalizations.delegate,
    ],
  ))
  .build();
```

## 贡献

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License
