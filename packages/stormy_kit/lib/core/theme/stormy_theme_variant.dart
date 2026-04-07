import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'variants/theme_variant.dart';

/// Stormy 默认浅色主题变体
/// 可继承此类以创建自定义浅色主题
class StormyLightThemeVariant extends StormyThemeVariant {
  StormyLightThemeVariant();

  @override
  String get name => 'stormy_light';

  @override
  Brightness get brightness => Brightness.light;

  // ==================== Material3 基础颜色 ====================

  @override
  Color get primary => const Color(0xFFFDAB1E);

  @override
  Color get secondary => const Color(0xFF111827);

  @override
  Color get error => const Color(0xFFF74F60);

  @override
  Color get background => const Color(0xFFEDF0F6);

  // ==================== 自定义扩展颜色 ====================

  @override
  Color get scaffoldBackground => const Color(0xFFF6F8FC);

  @override
  Color get bodyText => const Color(0xFF333333);

  @override
  Color get contentText => const Color(0xFF666666);

  @override
  Color get labelText => const Color(0xFF4B5563);

  @override
  Color get hintText => const Color(0xFF999999);

  @override
  Color get shadow => const Color.fromARGB(20, 107, 107, 107);

  // ==================== 圆角 ====================

  @override
  double get borderRadius => 16.r;

  // ==================== Material3 ColorScheme ====================

  @override
  ColorScheme get colorScheme => ColorScheme.light(
    primary: primary,
    secondary: secondary,
    error: error,
    surfaceBright: scaffoldBackground,
    surfaceContainerLow: scaffoldBackground,
    surfaceContainerLowest: scaffoldBackground,
    surfaceContainer: scaffoldBackground,
    surfaceContainerHigh: scaffoldBackground,
    surfaceContainerHighest: scaffoldBackground,
    outline: outline,
  );

  // ==================== Typography ====================

  @override
  TextStyle get titleStyle =>
      TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: bodyText);

  @override
  TextStyle get subtitleStyle =>
      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: bodyText);

  @override
  TextStyle get textStyle => TextStyle(fontSize: 14.sp, color: bodyText);

  @override
  TextStyle get appBarTitleStyle =>
      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: bodyText);

  @override
  TextStyle get contentStyle => TextStyle(fontSize: 14.sp, color: contentText);

  @override
  TextStyle get hintStyle => TextStyle(fontSize: 14.sp, color: hintText);

  @override
  TextStyle get labelStyle => TextStyle(fontSize: 12.sp, color: labelText);

  @override
  EdgeInsets get mainPadding => EdgeInsets.symmetric(horizontal: 32.w);

  @override
  double get spacingSmall => 8.w;

  @override
  double get spacingMedium => 16.w;

  @override
  double get spacingLarge => 24.w;

  @override
  double get spacingXLarge => 32.w;
}

/// Stormy 默认深色主题变体
/// 可继承此类以创建自定义深色主题
class StormyDarkThemeVariant extends StormyThemeVariant {
  StormyDarkThemeVariant();

  @override
  String get name => 'stormy_dark';

  @override
  Brightness get brightness => Brightness.dark;

  // ==================== Material3 基础颜色 ====================

  @override
  Color get primary => const Color(0xFFFDAB1E);

  @override
  Color get secondary => const Color(0xFFFFFFFF);

  @override
  Color get error => const Color(0xFFF74F60);

  @override
  Color get background => const Color(0xFF121212);

  // ==================== 自定义扩展颜色 ====================

  @override
  Color get scaffoldBackground => const Color(0xFF141414);

  @override
  Color get bodyText => const Color(0xFFFFFFFF);

  @override
  Color get contentText => const Color(0xFFB0B0B0);

  @override
  Color get labelText => const Color(0xFF808080);

  @override
  Color get hintText => const Color(0xFF606060);

  @override
  Color get shadow => const Color.fromARGB(40, 0, 0, 0);

  // ==================== 圆角 ====================

  @override
  double get borderRadius => 16.r;

  // ==================== Material3 ColorScheme ====================

  @override
  ColorScheme get colorScheme => ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    error: error,
    surfaceBright: scaffoldBackground,
    surfaceContainerLow: scaffoldBackground,
    surfaceContainerLowest: scaffoldBackground,
    surfaceContainer: scaffoldBackground,
    surfaceContainerHigh: scaffoldBackground,
    surfaceContainerHighest: scaffoldBackground,
    outline: outline,
  );

  // ==================== Typography ====================

  @override
  TextStyle get titleStyle =>
      TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: bodyText);

  @override
  TextStyle get subtitleStyle =>
      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: bodyText);

  @override
  TextStyle get textStyle => TextStyle(fontSize: 14.sp, color: bodyText);

  @override
  TextStyle get appBarTitleStyle =>
      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: bodyText);

  @override
  TextStyle get contentStyle => TextStyle(fontSize: 14.sp, color: contentText);

  @override
  TextStyle get hintStyle => TextStyle(fontSize: 14.sp, color: hintText);

  @override
  TextStyle get labelStyle => TextStyle(fontSize: 12.sp, color: labelText);

  @override
  EdgeInsets get mainPadding => EdgeInsets.symmetric(horizontal: 32.w);

  @override
  double get spacingSmall => 8.w;

  @override
  double get spacingMedium => 16.w;

  @override
  double get spacingLarge => 24.w;

  @override
  double get spacingXLarge => 32.w;
}
