import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

import '../../config/accessor/config_accessor.dart';
import 'variants/theme_variant.dart';

/// Stormy Theme - 主题管理器
/// 提供主题切换功能，整合 adaptive_theme
/// 使用方式：通过 stormy() 配置器配置，主题在 apply 时自动应用
class StormyTheme {
  StormyTheme._();

  /// 当前主题变体
  static StormyThemeVariant _currentVariant = StormyThemeVariant.lightDefault;

  /// 获取当前主题变体
  static StormyThemeVariant get currentVariant => _currentVariant;

  /// 获取当前主题模式
  static ThemeMode get themeMode => _themeMode;
  static ThemeMode _themeMode = ThemeMode.system;

  /// AdaptiveTheme 状态管理
  static AdaptiveThemeManager? _themeManager;

  /// 初始化主题
  /// 由 StormyConfig.apply() 调用
  static void initialize() {
    // 从 ConfigAccessor 读取配置
    final config = StormyConfigAccessor.theme;

    if (config != null) {
      // 使用配置的主题变体工厂创建实例
      _currentVariant = config.lightVariant;
      _themeMode = config.themeMode;
    } else {
      // 使用默认主题
      _currentVariant = StormyThemeVariant.lightDefault;
      _themeMode = ThemeMode.system;
    }
  }

  /// 设置浅色主题
  static void setLightMode(BuildContext context) {
    _currentVariant = _createLightVariant();
    _themeMode = ThemeMode.light;
    AdaptiveTheme.of(context).setLight();
    _notifyThemeChanged();
  }

  /// 设置深色主题
  static void setDarkMode(BuildContext context) {
    _currentVariant = _createDarkVariant();
    _themeMode = ThemeMode.dark;
    AdaptiveTheme.of(context).setDark();
    _notifyThemeChanged();
  }

  /// 设置跟随系统
  static void setSystemMode(BuildContext context) {
    _themeMode = ThemeMode.system;
    AdaptiveTheme.of(context).setSystem();
    _notifyThemeChanged();
  }

  /// 切换到指定主题变体
  static void setTheme(StormyThemeVariant variant) {
    _currentVariant = variant;
    _notifyThemeChanged();
  }

  /// 创建浅色变体实例
  /// 优先使用配置的工厂，否则使用默认变体
  static StormyThemeVariant _createLightVariant() {
    final config = StormyConfigAccessor.theme;
    return config?.lightVariant ?? StormyThemeVariant.lightDefault;
  }

  /// 创建深色变体实例
  /// 优先使用配置的工厂，否则使用默认变体
  static StormyThemeVariant _createDarkVariant() {
    final config = StormyConfigAccessor.theme;
    return config?.darkVariant ?? StormyThemeVariant.darkDefault;
  }

  /// 通知主题已更改
  static void _notifyThemeChanged() {
    // 尝试通过 AdaptiveTheme 通知
    AdaptiveThemeMode adaptiveMode;
    switch (_themeMode) {
      case ThemeMode.light:
        adaptiveMode = AdaptiveThemeMode.light;
      case ThemeMode.dark:
        adaptiveMode = AdaptiveThemeMode.dark;
      case ThemeMode.system:
        adaptiveMode = AdaptiveThemeMode.system;
    }
    _themeManager?.setThemeMode(adaptiveMode);
  }

  /// 获取浅色主题数据
  static ThemeData get lightThemeData => _createLightVariant().toThemeData();

  /// 获取深色主题数据
  static ThemeData get darkThemeData => _createDarkVariant().toThemeData();

  /// 获取主题模式
  static AdaptiveThemeMode get adaptiveThemeMode {
    switch (_themeMode) {
      case ThemeMode.light:
        return AdaptiveThemeMode.light;
      case ThemeMode.dark:
        return AdaptiveThemeMode.dark;
      case ThemeMode.system:
        return AdaptiveThemeMode.system;
    }
  }

  /// 创建 AdaptiveTheme Widget
  /// 应在 MaterialApp 外层包裹
  static Widget wrapWithAdaptiveTheme({
    required Widget Function(ThemeData light, ThemeData dark) builder,
  }) {
    return AdaptiveTheme(
      light: lightThemeData,
      dark: darkThemeData,
      initial: adaptiveThemeMode,
      builder: builder,
    );
  }

  /// 设置主题管理器
  static void setThemeManager(AdaptiveThemeManager? manager) {
    _themeManager = manager;
  }
}
