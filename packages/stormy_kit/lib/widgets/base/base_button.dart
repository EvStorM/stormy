import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../stormy_kit.dart';

class BaseButton extends StatelessWidget {
  const BaseButton({
    super.key,
    this.onPressed,
    this.text,
    this.child,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.fontSize,
    this.fontWeight,
    this.borderRadius,
    this.padding,
    this.hasHapticFeedback = true,
    this.isDisabled = false,
    this.isLoading = false,
    this.bgDecoration,
    this.disabledBackgroundColor,
    this.disabledTextColor,
  });
  final VoidCallback? onPressed;
  final String? text;
  final Widget? child;
  final Color? backgroundColor;
  final BoxDecoration? bgDecoration;
  final Color? textColor;
  final Color? borderColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? borderRadius;
  final EdgeInsets? padding;
  final bool hasHapticFeedback;
  final bool? isDisabled;
  final bool? isLoading;
  final Color? disabledBackgroundColor;
  final Color? disabledTextColor;
  @override
  Widget build(BuildContext context) {
    /// 添加节流
    final (onPressedFn, _) = FuncUtils.throttle(() {
      onPressed?.call();
    }, Duration(milliseconds: 1000));

    return ElevatedButton(
      onPressed: isDisabled == true || isLoading == true
          ? null
          : () {
              // 手机振动,轻微震动
              if (hasHapticFeedback) {
                HapticFeedback.lightImpact();
              }
              onPressedFn();
              // onPressed?.call();
            },
      style: ElevatedButton.styleFrom(
        padding: padding ?? EdgeInsets.zero,
        disabledForegroundColor: disabledTextColor,
        foregroundColor: textColor ?? Colors.white,
        disabledBackgroundColor: disabledBackgroundColor,
        side: BorderSide(color: borderColor ?? Colors.transparent),
        backgroundBuilder: (context, state, widget) => Container(
          decoration:
              bgDecoration ??
              BoxDecoration(
                color: isDisabled == true || isLoading == true
                    ? disabledBackgroundColor ?? Colors.transparent
                    : backgroundColor ?? StormyTheme.currentVariant.secondary,
              ),
          child: isDisabled == true
              ? Stack(
                  children: [
                    widget ?? const SizedBox(),
                    Positioned.fill(
                      child: Container(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                )
              : widget ?? const SizedBox(),
        ),
        elevation: 1,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            borderRadius ?? StormyTheme.currentVariant.borderRadius,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isLoading == true)
              Container(
                width: 14.r,
                height: 14.r,
                margin: EdgeInsets.only(right: 4.r),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 1.r,
                ),
              ),
            child ??
                Text(
                  text ?? '',
                  style: TextStyle(
                    fontSize: fontSize ?? 16.r,
                    fontWeight: fontWeight ?? FontWeight.w600,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
