# stormy_kit

统一配置编排与兼容聚合入口。网络/存储/预加载位于 core，设备能力位于 platform，App/Widgets 位于 UI；旧 `package:stormy_kit/stormy_kit.dart` 继续导出这些能力。

Flutter 3.47.1、Dart >=3.13。按需配置模块，`apply()` 返回含原异常与堆栈的报告，`build()` 失败抛出 `StormyInitializationException`。

```dart
import 'package:flutter/widgets.dart';
import 'package:stormy_kit/stormy_kit.dart';

Future<StormyConfigApplied> configureNetwork() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await stormy()
      .network(StormyNetworkConfig(baseUrl: 'https://api.example.com'))
      .build(apply: false);
  return config.apply();
}
```

完整启动、路由、持久化及资源释放见 [使用指南](../../docs/USAGE.md)。API 调整见 [迁移说明](../../docs/MIGRATION.md)。可运行示例在 [example](example/lib/main.dart)。

`StormyApp` 尊重 `AppModel.designSize`，`preferredOrientations: []` 将方向交回平台。弹窗需要绑定 `StormyDialog.navigatorKey`；Toast 使用 `SmartDialog.showToast`。

KV 键支持 String/int，整数与字符串不混用，前缀只应用字符串。预加载只释放内部创建的 ProviderContainer。
