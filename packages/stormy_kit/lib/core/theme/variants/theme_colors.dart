import 'package:flutter/material.dart';

/// 主题颜色 Mixin
/// 定义所有颜色相关的属性
mixin ThemeColors {
  // ==================== Material3 基础颜色 ====================

  /// 主色
  Color get primary;

  /// 次要色
  Color get secondary;

  /// 错误色
  Color get error;

  /// 警告色
  Color get warning => const Color(0xFFFF9800);

  /// 成功色
  Color get success => const Color(0xFF4CAF50);

  /// 背景色
  Color get background;

  /// 轮廓色
  Color get outline => const Color(0xFFE0E0E0);

  // ==================== 自定义扩展颜色 ====================

  /// 脚手架背景色
  Color get scaffoldBackground;

  /// 正文文字颜色
  Color get bodyText;

  /// 内容文字颜色（次要文字）
  Color get contentText;

  /// 标签文字颜色
  Color get labelText;

  /// 提示文字颜色
  Color get hintText;

  /// 主要文字色（特殊浅蓝绿色）
  Color get primaryText => const Color(0xFFBFF5F1);

  /// 阴影颜色
  Color get shadow;

  // ==================== Material3 ColorScheme ====================

  /// 生成 Material3 ColorScheme
  ColorScheme get colorScheme;

  /// 亮度
  Brightness get brightness;
}
