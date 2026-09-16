import 'package:flutter/material.dart';

import '../../core/theme/stormy_theme_variant.dart';
import '../../core/theme/variants/theme_variant.dart';

/// 主题变体工厂函数类型
/// 用于在需要时动态创建主题变体实例
typedef StormyThemeVariantFactory = StormyThemeVariant Function();

/// 主题配置工厂函数类型（可选）
/// 当需要时才调用创建默认变体
typedef StormyThemeVariantFactoryOrNull = StormyThemeVariant? Function();

/// Stormy Theme Config - 主题配置
/// 用于配置 Stormy 主题，支持主题色和自定义主题变体
class StormyThemeConfig {
  /// 主题色
  /// 用于自定义主题时覆盖默认主题色
  final Color? primaryColor;

  /// 浅色主题变体工厂
  /// 传入一个返回浅色主题变体的工厂函数
  /// 支持完全自定义（覆盖所有颜色、字体、间距等）
  final StormyThemeVariantFactoryOrNull lightVariantFactory;

  /// 深色主题变体工厂
  /// 传入一个返回深色主题变体的工厂函数
  /// 支持完全自定义（覆盖所有颜色、字体、间距等）
  final StormyThemeVariantFactoryOrNull darkVariantFactory;

  /// 主题模式
  /// 默认使用系统主题
  final ThemeMode themeMode;

  const StormyThemeConfig({
    this.primaryColor,
    StormyThemeVariantFactory? lightVariantFactory,
    StormyThemeVariantFactory? darkVariantFactory,
    this.themeMode = ThemeMode.system,
  }) : lightVariantFactory = lightVariantFactory ?? _defaultLightFactory,
       darkVariantFactory = darkVariantFactory ?? _defaultDarkFactory;

  static StormyThemeVariant? _defaultLightFactory() =>
      StormyLightThemeVariant();

  static StormyThemeVariant? _defaultDarkFactory() => StormyDarkThemeVariant();

  /// 创建浅色主题变体
  /// 如果配置了自定义工厂则使用它，否则返回默认变体
  StormyThemeVariant get lightVariant =>
      lightVariantFactory() ?? StormyLightThemeVariant();

  /// 创建深色主题变体
  /// 如果配置了自定义工厂则使用它，否则返回默认变体
  StormyThemeVariant get darkVariant =>
      darkVariantFactory() ?? StormyDarkThemeVariant();

  /// 创建默认配置
  factory StormyThemeConfig.defaults() {
    return const StormyThemeConfig();
  }

  /// 创建自定义配置
  /// [lightBuilder] 浅色主题构建器，接收浅色基础配置
  /// [darkBuilder] 深色主题构建器，接收深色基础配置
  factory StormyThemeConfig.custom({
    Color? primaryColor,
    required StormyThemeVariant Function(StormyLightThemeVariant base)
    lightBuilder,
    required StormyThemeVariant Function(StormyDarkThemeVariant base)
    darkBuilder,
    ThemeMode themeMode = ThemeMode.system,
  }) {
    return StormyThemeConfig(
      primaryColor: primaryColor,
      themeMode: themeMode,
      lightVariantFactory: () => lightBuilder(StormyLightThemeVariant()),
      darkVariantFactory: () => darkBuilder(StormyDarkThemeVariant()),
    );
  }

  /// 复制并修改配置
  StormyThemeConfig copyWith({
    Color? primaryColor,
    StormyThemeVariantFactory? lightVariantFactory,
    StormyThemeVariantFactory? darkVariantFactory,
    ThemeMode? themeMode,
  }) {
    return StormyThemeConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      lightVariantFactory:
          lightVariantFactory ?? (() => StormyLightThemeVariant()),
      darkVariantFactory:
          darkVariantFactory ?? (() => StormyDarkThemeVariant()),
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
