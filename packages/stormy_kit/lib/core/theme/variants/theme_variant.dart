import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../stormy_theme_variant.dart';
import 'theme_colors.dart';
import 'theme_decorations.dart';
import 'theme_dimensions.dart';
import 'theme_text.dart';
import 'theme_typography.dart';

/// 主题变体抽象基类
/// 组合所有主题相关的 Mixin
abstract class ThemeVariant
    with
        ThemeColors,
        ThemeTypography,
        ThemeDecorations,
        ThemeDimensions,
        ThemeText {
  /// 主题名称
  String get name;

  /// 转换为 Material ThemeData
  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      dividerColor: Colors.transparent,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: 'PingFang SC',
      textTheme: variantTextTheme.useSystemChineseFont(brightness),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(size: 16.r, color: primary),
        actionsIconTheme: IconThemeData(size: 16.r, color: primary),
        titleTextStyle: appBarTitleStyle,
        // 根据主题亮度设置状态栏样式：深色主题使用浅色图标，浅色主题使用深色图标
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
    );
  }
}

/// StormyThemeVariant - 框架提供的变体基类
/// 提供工厂方法和默认变体访问器
/// 继承此基类可获得更灵活的变体创建能力
abstract class StormyThemeVariant extends ThemeVariant {
  /// 创建浅色变体的工厂（供子类覆盖）
  static StormyThemeVariant createLight() => StormyLightThemeVariant();

  /// 创建深色变体的工厂（供子类覆盖）
  static StormyThemeVariant createDark() => StormyDarkThemeVariant();

  /// 获取浅色默认变体
  static StormyThemeVariant get lightDefault => StormyLightThemeVariant();

  /// 获取深色默认变体
  static StormyThemeVariant get darkDefault => StormyDarkThemeVariant();

  /// 获取默认变体（根据亮度）
  static StormyThemeVariant getDefault(Brightness brightness) =>
      brightness == Brightness.light ? lightDefault : darkDefault;

  /// 从配置创建变体
  /// [isDark] 是否为深色主题
  /// [factory] 变体工厂函数
  static StormyThemeVariant fromFactory({
    required bool isDark,
    required StormyThemeVariant Function() factory,
  }) {
    return factory();
  }
}
