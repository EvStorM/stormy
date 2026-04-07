import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

/// 自定义浅色主题变体示例
/// 继承内置浅色变体，覆盖部分属性
class CustomLightThemeVariant extends StormyLightThemeVariant {
  CustomLightThemeVariant();

  @override
  String get name => 'custom_light';

  @override
  Color get primary => const Color(0xFF2196F3);

  @override
  Color get scaffoldBackground => const Color(0xFFE3F2FD);
}

/// 自定义深色主题变体示例
/// 继承内置深色变体，覆盖部分属性
class CustomDarkThemeVariant extends StormyDarkThemeVariant {
  CustomDarkThemeVariant();

  @override
  String get name => 'custom_dark';

  @override
  Color get primary => const Color(0xFFFF00F6);

  @override
  Color get scaffoldBackground => const Color(0xFF0D1B2A);
}

/// Theme Demo Page
/// 展示 stormy_kit/core/theme 的使用方式
class ThemeDemoPage extends StatelessWidget {
  const ThemeDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BasePage(
      appBar: AppBar(
        title: const Text('StormyTheme Demo'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 颜色示例
            Text(
              'Colors',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ColorChip(label: 'Primary', color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                _ColorChip(
                    label: 'Secondary', color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                _ColorChip(label: 'Surface', color: theme.colorScheme.surface),
                const SizedBox(width: 12),
                _ColorChip(label: 'Error', color: theme.colorScheme.error),
              ],
            ),
            const SizedBox(height: 32),

            // 文字样式示例
            Text(
              'Typography',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Headline Large: ${theme.textTheme.headlineLarge?.fontSize}px',
                style: theme.textTheme.headlineLarge),
            Text('Title Large: ${theme.textTheme.titleLarge?.fontSize}px',
                style: theme.textTheme.titleLarge),
            Text('Body Large: ${theme.textTheme.bodyLarge?.fontSize}px',
                style: theme.textTheme.bodyLarge),
            Text('Body Medium: ${theme.textTheme.bodyMedium?.fontSize}px',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),

            // 主题切换按钮
            Text(
              'Theme Switch',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => StormyTheme.setLightMode(context),
                  child: const Text('Light'),
                ),
                ElevatedButton(
                  onPressed: () => StormyTheme.setDarkMode(context),
                  child: const Text('Dark'),
                ),
                ElevatedButton(
                  onPressed: () => StormyTheme.setSystemMode(context),
                  child: const Text('System'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 当前主题信息
            Text(
              'Current Theme Info',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Theme Mode: ${StormyTheme.themeMode}'),
            Text('Variant: ${StormyTheme.currentVariant.name}'),
            const SizedBox(height: 32),

            // Storage Demo 入口
            Text(
              'Storage Demo',
              style: theme.textTheme.titleLarge,
            ),

            const SizedBox(height: 12),
            BaseButton(
              text: '打开 Storage Demo',
              onPressed: () => context.push('/storage'),
            ),
            const SizedBox(height: 12),
            BaseButton(
              text: '打开 Network Demo',
              onPressed: () => context.push('/network'),
            ),
            const SizedBox(height: 12),
            BaseButton(
              text: '测试隐私协议弹窗',
              onPressed: () {
                // 测试期间每次都清除状态，以便能反复弹窗
                StormyStorage.instance.remove('stormy_privacy_agreed');

                StormyDialog.instance.showPrivacyDialog(
                  context,
                  onDone: () {},
                  overrideConfig: StormyPrivacyConfig(
                    uiConfig: PrivacyDialogConfig(
                      body: PrivacyBodyConfig(contentParagraphs: [
                        '感谢您信任并使用我们的产品。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                        '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
                      ]),
                      footer: PrivacyFooterConfig(
                        direction: Axis.vertical,
                        disagreeDecoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.purpleAccent,
                              Colors.blueAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        agreeDecoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.purpleAccent],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      exitConfirm: const PrivacyExitConfirmConfig(
                        title: '定制拦截标题',
                        content: '这里是定制的警告拦截副文本！是否残忍拒绝？',
                        cancelText: '我再想想',
                        confirmText: '残忍拒绝',
                        confirmTextColor: Colors.purple,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
