# stormy_i18n

[English](README.md) | [中文](README_zh.md)

`stormy_i18n` 是一个专为 Flutter 打造的多语言（I18n）效率工具，告别手写繁杂易错且缺乏类型关联验证的 `.arb` JSON 文件弊端。它允许开发者直接在纯 Dart 环境中以强类型约束构建结构树（通过 `I18nItem`）编写所有文案组合配置。它底层基于源文件映射解析，并由 CLI 工具桥接出标准化的 `ARB` 并直接驱动 `flutter gen-l10n` 原生代码生成流程。

### 核心功能
- **纯 Dart 配置：** 所有的多语言文本均可统一为直观的类静态变量，和您的应用代码无缝结合存放。
- **自动 ARB 构建：** 免去了接触 `.arb` 语法的过程，生成器底层自动化扫描并产出 ARB，零心智负担。
- **严格的安全类型：** 完善封装 `I18nPlaceholder` 构建包括 ICU 格式（支持复数、货币、日期和时间等）。
- **实时常驻监听：** CLI 支持 `--watch` 监听修改特征，一旦修改任意文本字段代码便触发极速局部热更新体系。
- **应用内状态管理：** 自带且极度轻量的初始化切换机与存储回调系统（`StormyI18n.init/changeLocale`），与视图联动极为方便。
- **BuildContext 拓展扩展支持：** 高性能地直接利用 `context.l10n.xxx` 获取字段强类型提示属性。

### 简单使用说明

1. **安装依赖到配置**
在项目的 `pubspec.yaml` 引入此依赖及内置的原生多语言 sdk：
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  stormy_i18n: any # 拉取最新版本

flutter:
  generate: true # 重点：须启用底层代码生成引擎
```

2. **初始化配置**
执行下述命令，将在项目中生成脚手架配置文件 `stormy_i18n.yaml` 及配套的代码工具类（默认为 `lib/i18n/`）：
```bash
dart run stormy_i18n init
```

3. **创建或定义多语言字段**
在配置好的目录（如自带建立的 `example.dart` 或者自行新建内容）添加如下的实例并引用脚手架自动产生的包：
```dart
import 'stormy_i18n.dart'; 

class AppTexts {
  static const appName = I18nItem(
    zh: '我的应用',
    en: 'My App',
  );
}
```

4. **一次性生成及挂载**
主动跑一次扫描：
```bash
dart run stormy_i18n gen
```
这将在底层产出所需要的拓展代码，接下来通过 `context.l10n` 在视图里开始使用：
```dart
import 'i18n/stormy_i18n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StormyI18n.init(); // 驱动加载语言缓存初始化器
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: StormyI18n.localeNotifier,
      builder: (_, locale, __) {
        return MaterialApp(
          locale: locale,                 // 挂载通知变量
          supportedLocales: StormyLocales.supportedLocales, 
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        );
      }
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 拓展调用获得极致的 IDE 字段代码自动补全提示：
    return Text(context.l10n.appName);
  }
}
```

### 高级功能说明

#### 1. 动态灵活的占位符配置参数映射
结合 `I18nPlaceholder` 特性，能够方便地将各种带参数的类型如货币、日期转化机制应用进去：

```dart
class AdvancedTexts {
  // 复数形态语法规范
  static const nWombats = I18nItem(
    description: '数量袋熊词汇的说明',
    zh: '{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    en: '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
    placeholders: {
      'count': I18nPlaceholder.int(format: 'compact'),
    },
  );

  // 定制化的日期展示拦截
  static const dateInfo = I18nItem(
    zh: '今天日期是 {date}',
    en: 'Today is {date}',
    placeholders: {
      'date': I18nPlaceholder.dateTime(format: 'yMd'),
    },
  );
}
```

#### 2. 常驻监听模式 (Watch 自动重启)
为了在 UI 调整测试期间拥有最高的效率响应，支持一直开着进程拦截 Dart 文案的代码写入行为：
```bash
dart run stormy_i18n watch
```
当保存 `lib/i18n/` 中所有的含有 `.dart` 的文案表的时候，插件就会根据防抖动安全措施无缝覆盖底层的 ARB 以及刷新。

#### 3. 与本地缓存方案无缝组合的状态变更方案
在 App 重启或者手动切换语言的情况下往往需要把 `Locale` 记录进本地内存。利用初始化的入参接口接管存取事件即可实现逻辑的彻底闭环操作，下面的示例搭配了 `SharedPreferences` 作为持久化方案：
```dart
await StormyI18n.init(
  defaultLocale: const Locale('en'),
  // 控制器提取缓存触发钩子
  localeResolver: () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString('language');
    if (cache == null) return null;
    final parts = cache.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  },
  // 手动调换语言时向控制器注册监听以抛出持久化处理的钩子事件
  onSave: (locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      prefs.remove('language'); // null 意味着将切换至当前手机硬件的首选系统级默认设置
    } else {
      prefs.setString('language', locale.toString()); // 诸如 'zh_CN' 数据写入方案保存等
    }
  },
);

// 此时只要在代码的任何角落想要无感切换用户界面特定语言，运行这行立刻覆盖上下文！
await StormyI18n.changeLocale(const Locale('zh', 'CN'));
```
