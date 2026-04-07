import 'dart:typed_data';

import 'package:example/src/head_info.dart';
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

import 'src/theme.dart';
import 'src/storage_demo.dart';
import 'src/network_demo.dart';

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
        routes: [
          GoRoute(path: '/', builder: (context, state) => ThemeDemoPage()),
          GoRoute(
              path: '/storage',
              builder: (context, state) => const StorageDemoPage()),
          GoRoute(
              path: '/network',
              builder: (context, state) => const NetworkDemoPage()),
        ],
      ),
    );
  }
}
