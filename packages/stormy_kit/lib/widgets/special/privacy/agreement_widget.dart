import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../stormy_kit.dart';

/// 协议项模型，包含协议名称和URL
class AgreeItemModel {
  const AgreeItemModel({required this.label, required this.agreeUrl});

  /// 协议标签名称 (如《用户协议》)
  final String label;

  /// 协议URL地址
  final String agreeUrl;
}

/// 协议分段基础类
abstract class AgreementSegment {
  const AgreementSegment();
}

/// 纯文本分段
class TextSegment extends AgreementSegment {
  final String text;
  final TextStyle? style;

  const TextSegment(this.text, {this.style});
}

/// 协议链接分段
class ProtocolSegment extends AgreementSegment {
  final AgreeItemModel protocol;
  final TextStyle? style;

  /// 自定义点击事件，如果为空则走组件默认事件
  final VoidCallback? onTap;

  const ProtocolSegment(this.protocol, {this.style, this.onTap});
}

/// 协议同意组件
///
/// 使用最优设计，支持完全的样式解耦与高度自定义。
/// 能够灵活调整布局、文本颜色大小、协议颜色大小与图标大小。
class AgreementWidget extends StatelessWidget {
  const AgreementWidget({
    super.key,
    required this.isChecked,
    required this.onChanged,
    required this.segments,
    this.showCheckbox = true,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.textAlign = TextAlign.start,
    this.iconSize = 18.0,
    this.spacing = 8.0,
    this.checkIcon,
    this.unCheckIcon,
    this.iconColor,
    this.uncheckIconColor,
    this.textStyle,
    this.protocolStyle,
    this.onProtocolTap,
  });

  /// 当前是否已勾选
  final bool isChecked;

  /// 勾选状态变化回调
  final ValueChanged<bool> onChanged;

  /// 协议文本分段数据，分离数据与样式
  final List<AgreementSegment> segments;

  /// 是否显示复选框
  final bool showCheckbox;

  /// 整体行布局的横向对齐方式
  final MainAxisAlignment mainAxisAlignment;

  /// 富文本多行时的排版对齐方式
  final TextAlign textAlign;

  /// 复选框大小
  final double iconSize;

  /// 复选框与文本的间距
  final double spacing;

  /// 自定义选中图标路径
  final String? checkIcon;

  /// 自定义未选中图标路径
  final String? unCheckIcon;

  /// 默认图标选中时的颜色（仅在使用默认 Icon 时生效）
  final Color? iconColor;

  /// 默认图标未选中时的颜色（仅在使用默认 Icon 时生效）
  final Color? uncheckIconColor;

  /// 默认基础文本样式 (颜色/大小/字重等)
  final TextStyle? textStyle;

  /// 默认高亮协议的文本样式 (颜色/大小/字重等)
  final TextStyle? protocolStyle;

  /// 统一的协议点击拦截回调
  /// 返回 true 代表已手动处理，不再跳转默认 H5 路由
  final bool Function(BuildContext context, AgreeItemModel protocol)?
  onProtocolTap;

  @override
  Widget build(BuildContext context) {
    // 获取基准文本样式
    final defaultStyle =
        textStyle ??
        TextStyle(fontSize: 13.sp, color: StormyTheme.currentVariant.hintText);

    final resolvedFontSize = defaultStyle.fontSize ?? 13.sp;
    final resolvedLineHeightWeight = defaultStyle.height ?? 1.4; 
    
    // 估算首行文字的视觉高度
    final firstLineHeight = resolvedFontSize * resolvedLineHeightWeight;
    
    // 计算对齐偏移量，确保 Checkbox 始终与首行文字垂直居中对齐
    double iconTopOffset = 0.0;
    double textTopOffset = 0.0;
    
    if (showCheckbox) {
      if (firstLineHeight > iconSize) {
        iconTopOffset = (firstLineHeight - iconSize) / 2;
      } else {
        textTopOffset = (iconSize - firstLineHeight) / 2;
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!isChecked);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: mainAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复选框部分
            if (showCheckbox) ...[
              Padding(
                padding: EdgeInsets.only(top: iconTopOffset),
                child: _buildCheckbox(),
              ), 
              SizedBox(width: spacing.w),
            ],

            // 文本内容部分
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(top: textTopOffset),
                child: _buildTextContent(context, defaultStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建复选框部分
  Widget _buildCheckbox() {
    return AgreementCheckbox(
      isChecked: isChecked,
      size: iconSize,
      checkIcon: checkIcon,
      unCheckIcon: unCheckIcon,
      iconColor: iconColor,
      uncheckIconColor: uncheckIconColor,
    );
  }

  /// 构建文本内容
  Widget _buildTextContent(BuildContext context, TextStyle defaultStyle) {
    // 根据主题配置兜底默认协议样式
    final defaultProtocolStyle =
        protocolStyle ??
        TextStyle(
          fontSize: 13.sp,
          color: StormyTheme.currentVariant.primary,
          decorationColor: StormyTheme.currentVariant.primary,
        );

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: defaultStyle,
        children: segments.map((segment) {
          if (segment is TextSegment) {
            return TextSpan(text: segment.text, style: segment.style);
          } else if (segment is ProtocolSegment) {
            final gestureRecognizer = TapGestureRecognizer()
              ..onTap = () {
                if (segment.onTap != null) {
                  segment.onTap!();
                  return;
                }
                final handled =
                    onProtocolTap?.call(context, segment.protocol) ?? false;
                if (!handled) {
                  _showAgreementDialog(context, segment.protocol);
                }
              };

            return TextSpan(
              text: segment.protocol.label,
              style: segment.style ?? defaultProtocolStyle,
              recognizer: gestureRecognizer,
            );
          }
          return const TextSpan();
        }).toList(),
      ),
    );
  }

  /// 显示默认协议详情弹窗 (底部弹起 H5)
  static void _showAgreementDialog(
    BuildContext context,
    AgreeItemModel agreeItem,
  ) {
    showBarModalBottomSheet(
      useRootNavigator: true,
      context: context,
      enableDrag: false,
      topControl: const SizedBox.shrink(),
      builder: (context) => H5(
        extra: {
          'title': agreeItem.label,
          'showTitle': true,
          'url': agreeItem.agreeUrl,
          "padding": EdgeInsets.zero,
        },
      ),
    );
  }
}

/// 协议复选框组件
///
/// 独立的纯UI组件，提高渲染性能
class AgreementCheckbox extends StatelessWidget {
  const AgreementCheckbox({
    super.key,
    required this.isChecked,
    this.size = 18.0,
    this.checkIcon,
    this.unCheckIcon,
    this.iconColor,
    this.uncheckIconColor,
  });

  /// 选中图标
  final String? checkIcon;

  /// 未选中图标
  final String? unCheckIcon;

  /// 选中颜色
  final Color? iconColor;

  /// 未选中颜色
  final Color? uncheckIconColor;

  /// 是否选中
  final bool isChecked;

  /// 复选框大小
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedCheckIcon =
        checkIcon ?? StormyConfigAccessor.assets?.checkIcon;
    final resolvedUncheckIcon =
        unCheckIcon ?? StormyConfigAccessor.assets?.unCheckIcon;

    // 如果配置了自定义图标，则使用图片
    if (resolvedCheckIcon != null && resolvedUncheckIcon != null) {
      return SizedBox(
        width: size.r,
        height: size.r,
        child: Image.asset(
          isChecked ? resolvedCheckIcon : resolvedUncheckIcon,
          width: size.r,
          height: size.r,
        ),
      );
    }

    // 否则使用默认的 Material Icon 选中组件
    return SizedBox(
      width: size.r,
      height: size.r,
      child: Icon(
        isChecked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: size.r,
        color: isChecked
            ? (iconColor ?? StormyTheme.currentVariant.primary)
            : (uncheckIconColor ?? StormyTheme.currentVariant.hintText.withAlpha(128)),
      ),
    );
  }
}
