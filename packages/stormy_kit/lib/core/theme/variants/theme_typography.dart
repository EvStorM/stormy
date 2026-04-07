import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme_colors.dart';

/// 主题文字样式 Mixin
/// 定义所有文字样式相关的属性
mixin ThemeTypography on ThemeColors {
  // ==================== 标题样式 ====================

  /// 大标题样式
  TextStyle get titleStyle => TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.w700,
    color: bodyText,
    letterSpacing: -1,
  );

  /// 副标题样式
  TextStyle get subtitleStyle =>
      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: bodyText);

  /// 普通文本样式
  TextStyle get textStyle =>
      TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: bodyText);

  // ==================== 特定用途样式 ====================

  /// AppBar 标题样式
  TextStyle get appBarTitleStyle =>
      TextStyle(fontSize: 20.sp, color: bodyText, fontWeight: FontWeight.w500);

  /// 内容文字样式
  TextStyle get contentStyle => TextStyle(
    fontSize: 12.sp,
    color: contentText,
    fontWeight: FontWeight.w400,
  );

  /// 提示文字样式
  TextStyle get hintStyle =>
      TextStyle(fontSize: 10.sp, color: hintText, fontWeight: FontWeight.w400);

  /// 标签文字样式
  TextStyle get labelStyle =>
      TextStyle(fontSize: 10.sp, color: labelText, fontWeight: FontWeight.w400);
}
