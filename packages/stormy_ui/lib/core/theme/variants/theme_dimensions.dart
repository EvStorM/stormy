import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 主题尺寸规范 Mixin
/// 定义所有尺寸相关的属性
mixin ThemeDimensions {
  // ==================== 间距 ====================

  /// 主要内容间距（左右）
  static const double _padding = 20;

  /// 主要内容边距
  EdgeInsets get mainPadding => EdgeInsets.symmetric(horizontal: _padding.r);

  /// 小间距
  double get spacingSmall => 4.r;

  /// 中等间距
  double get spacingMedium => 8.r;

  /// 大间距
  double get spacingLarge => 12.r;

  /// 超大间距
  double get spacingXLarge => 16.r;
}
