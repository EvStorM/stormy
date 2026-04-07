// ignore_for_file: depend_on_referenced_packages
import 'package:example/l10n/stormy_i18n.dart';
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

class I18nDemoPage extends StatelessWidget {
  const I18nDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I18n Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前语言环境: ${StormyI18n.currentLocale?.languageCode ?? "系统"}_${StormyI18n.currentLocale?.countryCode ?? ""}',
              style: const TextStyle(fontSize: 18),
            ),
            Text(context.l10n.example_translations_hello_world_on(
              DateTime.now(),
              DateTime.now(),
              '张三',
              1,
              'male',
            )),
            const SizedBox(height: 20),
            BaseButton(
              text: '切换到中文',
              onPressed: () {
                StormyI18n.changeLocale(const Locale('zh', 'CN'));
              },
            ),
            const SizedBox(height: 12),
            BaseButton(
              text: '切换到英文',
              onPressed: () {
                StormyI18n.changeLocale(const Locale('en', 'US'));
              },
            ),
            const SizedBox(height: 30),
            const Text(
              '注：\n利用 StormyI18n 配合 flutter_localizations，并在这里改变 Locale 后，整个应用的显示语言（如包含国际化的 Widgets）会自动刷新。在 StormyKitConfig 中，I18n配置会自动将当前 Locale 持久化到 Storage。',
              style: TextStyle(color: Colors.grey),
            )
          ],
        ),
      ),
    );
  }
}
