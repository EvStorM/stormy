import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../stormy_kit.dart';

/// 显示底部弹窗的便捷方法
///
/// [context] - BuildContext
/// [child] - 弹窗内容组件
/// [minHeight] - 最小高度比例 (0.0-1.0)，默认 0.5
/// [maxHeight] - 最大高度比例 (0.0-1.0)，默认 0.5
/// [maskColor] - 背景遮罩颜色，默认黑色透明度为1
/// [isDismissible] - 点击背景是否可关闭，默认 true
/// [enableDrag] - 是否启用拖拽关闭，默认 true
/// [onDismiss] - 弹窗关闭时的回调
///
/// 返回值：关闭时返回 false（如果设置了 onDismiss 回调，则先调用回调再返回）
Future<bool?> showBaseBottomSheet(
  BuildContext context, {
  required Widget child,
  double minHeight = 0.5,
  double maxHeight = 0.8,
  Color? maskColor,
  bool isDismissible = true,
  bool enableDrag = true,
  VoidCallback? onDismiss,
}) {
  return showMaterialModalBottomSheet<bool>(
    backgroundColor: Colors.transparent,
    context: context,
    expand: true,
    builder: (context) => BaseBottomSheet(
      minHeight: minHeight,
      maxHeight: maxHeight,
      maskColor: maskColor,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      onDismiss: onDismiss,
      child: child,
    ),
    useRootNavigator: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
  );
}

/// 基础底部弹窗组件
///
/// 提供一个可配置的底部弹窗，包含：
/// - 半透明黑色背景遮罩（点击可关闭）
/// - 底部弹出的内容容器
/// - 支持键盘弹出时自动调整底部内边距
class BaseBottomSheet extends StatelessWidget {
  const BaseBottomSheet({
    super.key,
    required this.child,
    this.minHeight = 0.5,
    this.maxHeight = 0.5,
    this.maskColor,
    this.isDismissible = true,
    this.enableDrag = true,
    this.onDismiss,
  });

  /// 弹窗内容组件
  final Widget child;

  /// 最小高度比例 (0.0-1.0)
  final double minHeight;

  /// 最大高度比例 (0.0-1.0)
  final double maxHeight;

  /// 背景遮罩颜色，默认黑色透明度为1
  final Color? maskColor;

  /// 点击背景是否可关闭
  final bool isDismissible;

  /// 是否启用拖拽关闭
  final bool enableDrag;

  /// 弹窗关闭时的回调
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      height: 1.sh,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Stack(
        children: [
          // 背景遮罩层
          GestureDetector(
            onTap: isDismissible
                ? () {
                    onDismiss?.call();
                    Navigator.of(context).pop(false);
                  }
                : null,
            child: Container(
              width: 1.sw,
              height: 1.sh,
              color: maskColor ?? Colors.black.withAlpha(1),
            ),
          ),
          // 底部内容区域
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BaseParent(
                child: Container(
                  width: 1.sw,
                  constraints: BoxConstraints(
                    minHeight: minHeight.sh,
                    maxHeight: maxHeight.sh,
                  ),
                  decoration: BoxDecoration(
                    color: StormyTheme.currentVariant.scaffoldBackground,
                    borderRadius: BorderRadius.circular(
                      StormyTheme.currentVariant.borderRadius,
                    ),
                  ),
                  child: BaseParent(
                    child: SizedBox(width: 1.sw, child: child),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
