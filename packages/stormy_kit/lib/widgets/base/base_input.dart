import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../stormy_kit.dart';

/// 校验状态
/// - null: 未进行校验
/// - true: 校验通过
/// - false: 校验失败
enum ValidationState { none, passed, failed }

class BaseInput extends StatefulWidget {
  const BaseInput({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLength = 1000,
    this.maxLines = 1,
    this.hideBorder = true,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.focusNode,
    this.onChanged,
    this.hintStyle,
    this.fillColor,
    this.style,
    this.height,
    this.hint,
    this.borderRadius,
    this.ondone,
    this.validator,
  });
  final TextEditingController controller;
  final String? hintText;
  final TextStyle? hintStyle;
  final TextStyle? style;
  final int maxLength;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final Function(String)? onChanged;
  final Color? fillColor;
  final double? height;
  final Widget? hint;
  final double? borderRadius;
  final bool hideBorder;
  final VoidCallback? ondone;
  final bool Function(String value)? validator;

  @override
  State<BaseInput> createState() => _BaseInputState();
}

class _BaseInputState extends State<BaseInput> {
  /// 校验状态
  ValidationState _validationState = ValidationState.none;

  /// 焦点状态管理（用于外部未传入 focusNode 时内部管理）
  FocusNode? _internalFocusNode;

  /// 获取焦点节点
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  /// 错误颜色
  static const Color _errorColor = Color(0xFFF74F60);

  @override
  void initState() {
    super.initState();
    // 如果外部未传入 focusNode，创建内部 focusNode
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    // 只释放内部创建的 focusNode
    _internalFocusNode?.dispose();
    super.dispose();
  }

  /// 处理输入变化
  void _handleOnChanged(String value) {
    // 调用原有的 onChanged 回调
    widget.onChanged?.call(value);

    // 当用户开始输入时，重置校验状态
    if (_validationState != ValidationState.none && value.isNotEmpty) {
      // 检查是否是删除操作（变短了），如果是则重置状态
      if (value.length < widget.maxLength) {
        setState(() {
          _validationState = ValidationState.none;
        });
      }
    }

    // 如果 ondone 不为 null，则在达到 maxLength 时进行校验并执行 ondone
    if (widget.ondone != null && value.length == widget.maxLength) {
      if (widget.validator == null) {
        // 无需校验，直接执行 ondone
        widget.ondone!();
      } else {
        // 进行校验
        final isValid = widget.validator!(value);
        setState(() {
          _validationState = isValid
              ? ValidationState.passed
              : ValidationState.failed;
        });
        if (isValid) {
          widget.ondone!();
        }
      }
    }
  }

  /// 获取边框颜色
  Color _getBorderColor({bool isFocused = false}) {
    if (_validationState == ValidationState.failed) {
      return _errorColor;
    }
    // 聚焦时使用稍微明显的边框，基于背景色增亮
    if (isFocused && _validationState == ValidationState.none) {
      final baseColor =
          widget.fillColor ?? StormyTheme.currentVariant.background;
      return Color.lerp(baseColor, Colors.white, 0.2)!;
    }
    return Colors.transparent;
  }

  /// 构建带有动态边框的 OutlineInputBorder
  OutlineInputBorder _buildOutlineInputBorder({
    required double radius,
    bool isFocused = false,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: widget.hideBorder
          ? BorderSide.none
          : BorderSide(
              color: _getBorderColor(isFocused: isFocused),
              width: _validationState == ValidationState.failed ? 1 : 1,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          widget.borderRadius ?? StormyTheme.currentVariant.borderRadius,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Builder(
        builder: (context) {
          try {
            return TextField(
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.center,
              focusNode: _focusNode,
              onChanged: _handleOnChanged,
              controller: widget.controller,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              style: widget.style,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              // 隐藏计数
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    return Container();
                  },
              decoration: InputDecoration(
                alignLabelWithHint: true,
                hint: widget.hint,
                hintText: widget.hintText,
                constraints: BoxConstraints(minHeight: widget.height ?? 24.r),
                hintStyle:
                    widget.hintStyle ??
                    TextStyle(
                      color: StormyTheme.currentVariant.contentText,
                      fontSize: 14.r,
                      height: 2,
                    ),
                filled: true,
                fillColor:
                    widget.fillColor ?? StormyTheme.currentVariant.background,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 6.r,
                  horizontal: 16.r,
                ),
                // 添加动态边框
                border: _buildOutlineInputBorder(
                  radius: StormyTheme.currentVariant.borderRadius,
                ),
                focusedBorder: _buildOutlineInputBorder(
                  radius:
                      widget.borderRadius ??
                      StormyTheme.currentVariant.borderRadius,
                  isFocused: true,
                ),
                enabledBorder: _buildOutlineInputBorder(
                  radius:
                      widget.borderRadius ??
                      StormyTheme.currentVariant.borderRadius,
                ),
                disabledBorder: _buildOutlineInputBorder(
                  radius:
                      widget.borderRadius ??
                      StormyTheme.currentVariant.borderRadius,
                ),
                errorBorder: _buildOutlineInputBorder(
                  radius:
                      widget.borderRadius ??
                      StormyTheme.currentVariant.borderRadius,
                ),
                focusedErrorBorder: _buildOutlineInputBorder(
                  radius:
                      widget.borderRadius ??
                      StormyTheme.currentVariant.borderRadius,
                  isFocused: true,
                ),
              ),
            );
          } catch (e) {
            // 如果controller已被dispose，返回空组件避免错误
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
