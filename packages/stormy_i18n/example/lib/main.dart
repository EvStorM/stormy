import 'package:flutter/cupertino.dart';
import 'package:stormy_i18n/stormy_i18n.dart';
import 'package:flutter/material.dart';

import 'l10n/stormy_i18n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化核心状态调度器（这里演示纯静默跟随系统，如果需要本地持久化，可在此时读取配置）
  await StormyI18n.init(defaultLocale: const Locale('en', 'US'));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: StormyI18n.localeNotifier,
      builder: (context, currentLocale, child) {
        return MaterialApp(
          // 将 locale 绑定到 StormyI18n 的通知器上
          locale: currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyWidget(),
        );
      },
    );
  }
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final curLocale = StormyI18n.currentLocale?.toString() ?? '跟随系统';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('当前语言状态: $curLocale',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoButton(
                  color: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => StormyI18n.changeLocale(null),
                  child: const Text("跟随系统"),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () => StormyI18n.changeLocale(const Locale('zh')),
                  child: const Text("中文"),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () =>
                      StormyI18n.changeLocale(const Locale('zh', "CN")),
                  child: const Text("简体中文"),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  color: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () =>
                      StormyI18n.changeLocale(const Locale('zh', "TW")),
                  child: const Text("繁體中文"),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  color: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () =>
                      StormyI18n.changeLocale(const Locale('en', "US")),
                  child: const Text("English"),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Text(context.l10n.example_translations_hello_world_on(
                DateTime.now(), DateTime.now(), "Evil's", 1, "male")),
            Text(context.l10n.example_translations_hello_world_on(
                DateTime.now(), DateTime.now(), "Alice", 3, "female")),
          ],
        ),
      ),
    );
  }
}
