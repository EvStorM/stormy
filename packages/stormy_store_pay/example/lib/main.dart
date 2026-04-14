import 'package:flutter/material.dart';

import 'store_pay_page.dart';

/// 所有测试产品 ID（与 Configuration.storekit 保持一致）
const allProductIds = [
  // 消耗型
  'stormy.store.coins.hundred',
  'stormy.store.energy.ten',
  // 非消耗型
  'stormy.store.package',
  // 非续期订阅
  'stormy.store.thirty',
  // 自动续期订阅
  'stormy.store.monthly',
  'stormy.store.weekly',
  'stormy.store.yearly',
];

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store Pay Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const StorePayExamplePage(),
    );
  }
}
