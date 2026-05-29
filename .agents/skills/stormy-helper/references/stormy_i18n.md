# Stormy I18n (`stormy_i18n`) 多语言开发与状态绑定指南

`stormy_i18n` 是一个专为 Flutter 打造的多语言效率工具，摆脱了手写繁琐且缺乏类型安全的 `.arb`（JSON）文件弊端。它允许开发者直接在纯 Dart 代码中声明强类型的文案配置树，并由底层 CLI 解析器桥接驱动 `flutter gen-l10n` 原生代码生成。

---

## 1. 纯 Dart 定义多语言字段 (`I18nItem`)

在规划的目录下（如 `lib/i18n/app_texts.dart`）以类静态变量方式声明语言包：

```dart
import 'stormy_i18n.dart';

class AppTexts {
  // 1. 基础 KV 声明
  static const appName = I18nItem(
    zh: '我的应用',
    en: 'My App',
  );

  // 2. 带占位符参数的声明
  static const welcomeUser = I18nItem(
    zh: '欢迎回来，{username}！',
    en: 'Welcome back, {username}!',
    placeholders: {
      'username': I18nPlaceholder.string(),
    },
  );
}
```

### 1.1 高级 ICU 占位符格式化

`I18nPlaceholder` 支持对各种复杂变量的输出样式进行底层约束：

```dart
class AdvancedTexts {
  // 复数形态语法规范
  static const nWombats = I18nItem(
    zh: '{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    en: '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
    placeholders: {
      'count': I18nPlaceholder.int(format: 'compact'), // 支持紧凑格式，如 1K, 1M
    },
  );

  // 定制化的日期与时间展示拦截
  static const dateInfo = I18nItem(
    zh: '今天日期是 {date}',
    en: 'Today is {date}',
    placeholders: {
      'date': I18nPlaceholder.dateTime(format: 'yMd'), // 格式化为: 2026/05/29
    },
  );
}
```

---

## 2. 编译翻译资源 (CLI 命令行工具)

`stormy_i18n` 提供了开箱即用的编译器。

### 一次性构建

```bash
dart run stormy_i18n gen
```
这会扫描项目中的 `I18nItem` 类，在后台生成原生编译用的 `.arb` 文件，并自动触发 `flutter gen-l10n` 构建类型安全的代码。

### 实时常驻监听（推荐开发期使用）

```bash
dart run stormy_i18n watch
```
该命令会监听整个 `lib/i18n/` 目录下 `.dart` 文件的改动，一旦检测到保存，会进行**局部防抖重编译**，使得界面多语言修改几乎瞬间热更新。

---

## 3. 双向 Locale 状态持久化绑定

为了让用户选择的语言在 App 重启后依然生效，需要将 `StormyI18n.init()` 关联本地持久化方案（以下以 `SharedPreferences` 为例）：

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stormy_kit/stormy_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化
  await StormyI18n.init(
    defaultLocale: const Locale('zh'), // 默认兜底 Locale
    
    // localeResolver 钩子：App 启动时，自动读取本地持久化数据
    localeResolver: () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString('user_language');
      if (cache == null) return null; // 返回 null 则使用默认 defaultLocale
      
      final parts = cache.split('_');
      return Locale(parts[0], parts.length > 1 ? parts[1] : null);
    },
    
    // onSave 钩子：当调用 changeLocale 切换语言时，自动触发持久化逻辑
    onSave: (locale) async {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove('user_language'); // 传入 null 代表恢复系统默认设置
      } else {
        await prefs.setString('user_language', locale.toString()); // 缓存如 'zh_CN'
      }
    },
  );

  runApp(const MyApp());
}
```

---

## 4. UI 层渲染与切换

### 4.1 挂载与监听

在应用根节点包裹 `ValueListenableBuilder` 来响应语言切换：

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: StormyI18n.localeNotifier, // 绑定通知器
      builder: (context, locale, _) {
        return MaterialApp(
          locale: locale,
          supportedLocales: StormyLocales.supportedLocales, // 自动生成的多语言列表
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        );
      },
    );
  }
}
```

### 4.2 获取文案与切换 Locale

在任意 Widget 中，通过 Extension 优雅调用，完美获取 IDE 自动补全代码提示：

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            // 强类型自动补全
            Text(context.l10n.appName), 
            Text(context.l10n.welcomeUser('Developer')),
            
            // 触发 Locale 动态变更 (将自动触发 main 中注册的 onSave 存储)
            ElevatedButton(
              onPressed: () => StormyI18n.changeLocale(const Locale('en')),
              child: const Text('Switch to English'),
            ),
          ],
        ),
      ),
    );
  }
}
```
