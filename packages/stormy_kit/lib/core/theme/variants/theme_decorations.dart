import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme_colors.dart';

/// 主题装饰样式 Mixin
/// 定义所有装饰相关的属性
mixin ThemeDecorations on ThemeColors {
  // ==================== 圆角 ====================
  /// 默认圆角
  double get borderRadius => 8.r;
}
