import 'package:flutter/material.dart';

import 'stormy_theme.dart';
import 'variants/theme_variant.dart';

/// BuildContext 主题扩展
/// 提供便捷的主题颜色和内容访问方式
extension ThemeExtension on BuildContext {
  /// 获取当前主题变体
  ///
  /// 自动订阅主题变化，当主题切换时，调用了 context.theme 的组件会自动重建。
  ///
  /// 使用方式：
  /// ```dart
  /// final theme = context.theme;
  /// Text('Hello', style: theme.titleStyle);
  /// Container(color: theme.primary);
  /// ```
  StormyThemeVariant get theme {
    // 依赖 Theme.of(this) 来注册监听，当 MaterialApp 的主题重建时（例如由 AdaptiveTheme 触发）
    // 引用了 context.theme 的组件会被重新构建，从而获取最新的当前变体
    Theme.of(this);
    return StormyTheme.currentVariant;
  }
}
