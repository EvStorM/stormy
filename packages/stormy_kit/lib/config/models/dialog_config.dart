import 'package:flutter/material.dart';

/// 弹窗位置
enum StormyDialogPosition {
  /// 顶部
  top,

  /// 居中
  center,

  /// 底部
  bottom,
}

/// 弹窗 UI 配置 (统一支持各类弹窗样式重写)
class StormyDialogUIConfig {
  /// 背景色
  final Color? backgroundColor;

  /// 圆角半径
  final double? borderRadius;

  /// 标题文本样式
  final TextStyle? titleStyle;

  /// 内容文本样式
  final TextStyle? messageStyle;

  /// 确认按钮背景色
  final Color? confirmButtonColor;

  /// 确认按钮文本颜色
  final Color? confirmButtonTextColor;

  /// 取消按钮背景色
  final Color? cancelButtonColor;

  /// 取消按钮文本颜色
  final Color? cancelButtonTextColor;

  /// 确认按钮文字
  final String? confirmText;

  /// 取消按钮文字
  final String? cancelText;

  /// 遮罩层颜色
  final Color? barrierColor;

  /// 是否可点击遮罩关闭
  final bool? barrierDismissible;

  const StormyDialogUIConfig({
    this.backgroundColor,
    this.borderRadius,
    this.titleStyle,
    this.messageStyle,
    this.confirmButtonColor,
    this.confirmButtonTextColor,
    this.cancelButtonColor,
    this.cancelButtonTextColor,
    this.confirmText,
    this.cancelText,
    this.barrierColor,
    this.barrierDismissible,
  });

  /// 默认配置
  factory StormyDialogUIConfig.defaultConfig() {
    return const StormyDialogUIConfig(
      confirmText: '确认',
      cancelText: '取消',
      barrierDismissible: false,
    );
  }

  /// 复制并覆盖当前配置
  StormyDialogUIConfig copyWith({
    Color? backgroundColor,
    double? borderRadius,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    Color? confirmButtonColor,
    Color? confirmButtonTextColor,
    Color? cancelButtonColor,
    Color? cancelButtonTextColor,
    String? confirmText,
    String? cancelText,
    Color? barrierColor,
    bool? barrierDismissible,
  }) {
    return StormyDialogUIConfig(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      confirmButtonColor: confirmButtonColor ?? this.confirmButtonColor,
      confirmButtonTextColor: confirmButtonTextColor ?? this.confirmButtonTextColor,
      cancelButtonColor: cancelButtonColor ?? this.cancelButtonColor,
      cancelButtonTextColor: cancelButtonTextColor ?? this.cancelButtonTextColor,
      confirmText: confirmText ?? this.confirmText,
      cancelText: cancelText ?? this.cancelText,
      barrierColor: barrierColor ?? this.barrierColor,
      barrierDismissible: barrierDismissible ?? this.barrierDismissible,
    );
  }
  
  /// 与另一个配置进行合并（属性覆盖）
  StormyDialogUIConfig merge(StormyDialogUIConfig? other) {
    if (other == null) return this;
    return copyWith(
      backgroundColor: other.backgroundColor,
      borderRadius: other.borderRadius,
      titleStyle: other.titleStyle,
      messageStyle: other.messageStyle,
      confirmButtonColor: other.confirmButtonColor,
      confirmButtonTextColor: other.confirmButtonTextColor,
      cancelButtonColor: other.cancelButtonColor,
      cancelButtonTextColor: other.cancelButtonTextColor,
      confirmText: other.confirmText,
      cancelText: other.cancelText,
      barrierColor: other.barrierColor,
      barrierDismissible: other.barrierDismissible,
    );
  }
}

/// 全局 Dialog Config
/// 区分 Alert 和 Confirm 类型的默认配置，同时指定默认弹出位置
class StormyDialogConfig {
  /// 默认弹出位置
  final StormyDialogPosition defaultPosition;

  /// 单按钮 Alert 弹窗的默认配置
  final StormyDialogUIConfig alertConfig;

  /// 双按钮 Confirm 弹窗的默认配置
  final StormyDialogUIConfig confirmConfig;

  const StormyDialogConfig({
    this.defaultPosition = StormyDialogPosition.bottom,
    this.alertConfig = const StormyDialogUIConfig(),
    this.confirmConfig = const StormyDialogUIConfig(),
  });

  /// 获取系统初始默认配置
  factory StormyDialogConfig.defaultConfig() {
    return StormyDialogConfig(
      defaultPosition: StormyDialogPosition.bottom,
      alertConfig: StormyDialogUIConfig.defaultConfig(),
      confirmConfig: StormyDialogUIConfig.defaultConfig(),
    );
  }

  StormyDialogConfig copyWith({
    StormyDialogPosition? defaultPosition,
    StormyDialogUIConfig? alertConfig,
    StormyDialogUIConfig? confirmConfig,
  }) {
    return StormyDialogConfig(
      defaultPosition: defaultPosition ?? this.defaultPosition,
      alertConfig: alertConfig ?? this.alertConfig,
      confirmConfig: confirmConfig ?? this.confirmConfig,
    );
  }
}
