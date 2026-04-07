import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

import 'l10n/stormy_i18n.dart';
import 'src/head_info.dart';
import 'src/pages/home_page.dart';
import 'src/pages/theme_demo.dart';
import 'src/pages/storage_demo.dart';
import 'src/pages/network_demo.dart';
import 'src/pages/dialog_demo.dart';
import 'src/pages/widgets_demo.dart';
import 'src/pages/refresh_demo.dart';
import 'src/pages/i18n_demo.dart';

/// 生成测试用加密密钥（32字节 = 256位）
/// 警告：实际生产环境应从 flutter_secure_storage 等安全存储获取
Uint8List _getTestEncryptionKey() {
  return Uint8List.fromList(
    List.generate(32, (i) => (i * 7 + 13) % 256),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加密密钥
  final cipher = HiveAesCipher(_getTestEncryptionKey());

  // 多 Bucket 模式配置
  final storageConfig = StormyStorageConfig(buckets: [
    const StorageBucket(name: 'default', category: 'general'),
    StorageBucket(
        name: 'secure_data', encryptionCipher: cipher, category: 'setting'),
  ], defaultBucketName: 'default', registerAdapters: () {});

  await stormy()
      .network(StormyNetworkConfig(
        parsingConfig:
            ResponseParsingConfig(messageKey: "message", successCode: 200),
        baseUrl: "https://qiaopai.wzglob.top/api/open",
        defaultRequireToken: false, // 设置为 false 方便直接调用
      ))
      .storage(storageConfig)
      .i18n(StormyI18nConfig(
        defaultLocale: const Locale('zh', 'CN'),
        storageKey: 'example_app_locale',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ))
      .theme(
        StormyThemeConfig(
          themeMode: ThemeMode.system,
          lightVariantFactory: () => CustomLightThemeVariant(),
          darkVariantFactory: () => CustomDarkThemeVariant(),
        ),
      )
      .build();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    setHeaderInfo(context);
    return StormyApp(
      appModel: AppModel.defaults().copyWith(
        designSize: const Size(375, 812),
      ),
      router: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
              path: '/theme',
              builder: (context, state) => const ThemeDemoPage()),
          GoRoute(
              path: '/storage',
              builder: (context, state) => const StorageDemoPage()),
          GoRoute(
              path: '/network',
              builder: (context, state) => const NetworkDemoPage()),
          GoRoute(
              path: '/dialog',
              builder: (context, state) => const DialogDemoPage()),
          GoRoute(
              path: '/widgets',
              builder: (context, state) => const WidgetsDemoPage()),
          GoRoute(
              path: '/refresh',
              builder: (context, state) => const RefreshDemoPage()),
          GoRoute(
              path: '/i18n', builder: (context, state) => const I18nDemoPage()),
        ],
      ),
    );
  }
}
