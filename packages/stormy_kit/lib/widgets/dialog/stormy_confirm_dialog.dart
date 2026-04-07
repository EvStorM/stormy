import 'package:flutter/material.dart';

import '../../stormy_kit.dart';

/// 统一样式的 Confirm（确认）对话框 UI 组件 - 纯 UI 的 stateless
class StormyConfirmDialog extends StatelessWidget {
  /// 对话框的具体配置项
  final StormyDialogUIConfig config;

  /// 提示位置
  final StormyDialogPosition position;

  /// 要显示的具体文本信息（如果传了这个，不传 child）
  final String? content;

  /// 复杂的自定义文本内容组件（如果不传 content，可以传这个）
  final Widget? child;

  /// 标题
  final String title;

  const StormyConfirmDialog({
    super.key,
    required this.config,
    required this.position,
    this.content,
    this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
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

    final Color bgColor =
        config.backgroundColor ?? StormyTheme.currentVariant.background;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: margin,
        child: Column(
          mainAxisAlignment: isBottom
              ? MainAxisAlignment.end
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(color: bgColor, borderRadius: geometry),
              padding: EdgeInsets.symmetric(horizontal: 20.r),
              child: Column(
                children: [
                  SizedBox(height: isBottom ? 14.r : 20.r),
                  Row(
                    mainAxisAlignment: isBottom
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      if (isBottom)
                        SizedBox(width: 20.r), // offset for close icon
                      Text(
                        title,
                        style:
                            config.titleStyle ??
                            TextStyle(
                              fontSize: isBottom ? 16.r : 20.sp,
                              fontWeight: isBottom
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                      ),
                      if (isBottom)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop(false);
                          },
                          child: Icon(
                            Icons.close_outlined,
                            color: Colors.black54,
                            size: 20.r,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isBottom ? 20.r : 12.r),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child:
                            child ??
                            Text(
                              content ?? '',
                              style:
                                  config.messageStyle ??
                                  TextStyle(
                                    fontSize: isBottom ? 13.r : 16.sp,
                                    color: isBottom
                                        ? StormyTheme.currentVariant.labelText
                                        : StormyTheme.currentVariant.contentText
                                              .withAlpha(200),
                                    fontWeight: isBottom
                                        ? FontWeight.normal
                                        : FontWeight.w300,
                                    height: 1.5,
                                  ),
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.r),
                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48.r,
                          child: BaseButton(
                            padding: EdgeInsets.zero,
                            borderRadius: 999.r, // Rounded pill shape
                            borderColor: config.cancelButtonColor != null
                                ? Colors.transparent
                                : StormyTheme.currentVariant.secondary,
                            backgroundColor:
                                config.cancelButtonColor ?? Colors.transparent,
                            textColor:
                                config.cancelButtonTextColor ?? Colors.black,
                            child: Text(
                              config.cancelText ?? '取消',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 13.r),
                      Expanded(
                        child: SizedBox(
                          height: 48.r,
                          child: BaseButton(
                            padding: EdgeInsets.zero,
                            backgroundColor:
                                config.confirmButtonColor ??
                                StormyTheme.currentVariant.secondary,
                            textColor: config.confirmButtonTextColor,
                            borderRadius: 999.r,
                            child: Text(
                              config.confirmText ?? '确认',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isBottom ? 32.r : 20.r),
                  if (isBottom) BaseBottomPadding(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
