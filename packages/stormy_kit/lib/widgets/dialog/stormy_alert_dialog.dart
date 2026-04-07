import 'package:flutter/material.dart';

import '../../stormy_kit.dart';

/// 统一样式的 Alert（提示）对话框 UI 组件 - 纯 UI 的 stateless
class StormyAlertDialog extends StatelessWidget {
  /// 对话框的具体配置项 (已由上层计算并组合默认值)
  final StormyDialogUIConfig config;

  /// 提示位置，影响内边距、圆角等不同的样式渲染
  final StormyDialogPosition position;

  /// 要显示的信息
  final String content;

  /// 可选的标题
  final String? title;

  /// 自定义的显示组件
  final Widget? child;

  const StormyAlertDialog({
    super.key,
    required this.config,
    required this.position,
    required this.content,
    this.title,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 处理位置所对应的默认圆角、边距情况
    final bool isBottom = position == StormyDialogPosition.bottom;

    final double effectiveBorderRadius =
        config.borderRadius ?? StormyTheme.currentVariant.borderRadius;

    final BorderRadius geometry = isBottom
        ? BorderRadius.only(
            topLeft: Radius.circular(effectiveBorderRadius),
            topRight: Radius.circular(effectiveBorderRadius),
          )
        : BorderRadius.all(Radius.circular(effectiveBorderRadius));

    final EdgeInsets margin = isBottom
        ? EdgeInsets.zero
        : EdgeInsets.symmetric(horizontal: 24.r);

    return Scaffold(
      backgroundColor:
          Colors.transparent, // SmartDialog 或是 ModelBottomSheet 会处理外层遮罩，内部一定透明
      body: Container(
        margin: margin,
        child: Column(
          mainAxisAlignment: isBottom
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    config.backgroundColor ??
                    StormyTheme.currentVariant.background,
                borderRadius: geometry,
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.r),
              child: Column(
                children: [
                  SizedBox(height: isBottom ? 12.r : 20.r),
                  if (title != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title!,
                          style:
                              config.titleStyle ??
                              TextStyle(
                                fontSize: isBottom ? 36.r : 18.r,
                                fontWeight: FontWeight.w700,
                                color: StormyTheme.currentVariant.background,
                                // 注意：如果是浅色主题，原代码里 `StormyTheme.currentVariant.background` 当做黑色用了，这里最好保持原样，或不指定颜色交由配置
                              ),
                        ),
                      ],
                    ),
                    SizedBox(height: isBottom ? 20.r : 12.r),
                  ],
                  if (child != null)
                    child!
                  else
                    Row(
                      mainAxisAlignment: isBottom
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            content,
                            style:
                                config.messageStyle ??
                                TextStyle(
                                  fontSize: isBottom ? 28.r : 16.sp,
                                  color: isBottom
                                      ? Colors.black
                                      : StormyTheme.currentVariant.contentText
                                            .withAlpha(200),
                                  height: 1.5,
                                ),
                            textAlign: isBottom
                                ? TextAlign.center
                                : TextAlign.left,
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: isBottom ? 30.r : 20.r),
                  SizedBox(
                    width: isBottom ? 480.r : 1.sw,
                    height: isBottom ? null : 48.r,
                    child: BaseButton(
                      padding: isBottom ? null : EdgeInsets.zero,
                      fontSize: isBottom ? 32.r : 20.sp,
                      borderRadius: isBottom
                          ? 99.r
                          : null, // CenterAlert 未指定特殊的 BaseButton borderRadius
                      backgroundColor: config.confirmButtonColor,
                      textColor: config.confirmButtonTextColor,
                      text: config.confirmText ?? '确认',
                      onPressed: () {
                        // 返回 true
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ),
                  SizedBox(height: isBottom ? 32.r : 20.r),
                ],
              ),
            ),
            if (isBottom) BaseBottomPadding(),
          ],
        ),
      ),
    );
  }
}
