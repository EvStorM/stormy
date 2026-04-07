import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../stormy_kit.dart';

/// 头部配置
class PrivacyHeaderConfig {
  final String title;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;

  const PrivacyHeaderConfig({
    this.title = '服务协议和隐私条款',
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
  });
}

/// 确认退出弹窗配置
class PrivacyExitConfirmConfig {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final Color? cancelTextColor;
  final Color? confirmTextColor;

  const PrivacyExitConfirmConfig({
    this.title = '温馨提示',
    this.content = '不同意隐私政策将无法使用本应用，是否退出？',
    this.cancelText = '再看看',
    this.confirmText = '坚持退出',
    this.cancelTextColor,
    this.confirmTextColor = Colors.red,
  });
}

/// 底部配置
class PrivacyFooterConfig {
  final String agreeText;
  final String disagreeText;
  final Color? agreeBgColor;
  final Color? disagreeBgColor;
  final BoxDecoration? agreeDecoration;
  final BoxDecoration? disagreeDecoration;
  final Color? agreeTextColor;
  final Color? disagreeTextColor;
  final Axis direction;
  final double? buttonHeight;
  final double? buttonRadius;
  final double buttonSpacing;
  final FontWeight? fontWeight;
  final double? fontSize;

  const PrivacyFooterConfig({
    this.agreeText = '同意并接受',
    this.disagreeText = '不同意',
    this.agreeBgColor,
    this.disagreeBgColor,
    this.agreeDecoration,
    this.disagreeDecoration,
    this.agreeTextColor = Colors.white,
    this.disagreeTextColor = Colors.white,
    this.direction = Axis.horizontal,
    this.buttonHeight,
    this.buttonRadius,
    this.buttonSpacing = 8.0,
    this.fontWeight = FontWeight.w500,
    this.fontSize,
  });
}

/// 主体配置
class PrivacyBodyConfig {
  final double? minHeight;
  final double? maxHeight;
  final TextStyle? normalTextStyle;
  final TextStyle? highlightTextStyle;
  final List<String> contentParagraphs;
  final String userAgreementName;
  final String privacyPolicyName;
  final String userAgreementUrl;
  final String privacyPolicyUrl;

  const PrivacyBodyConfig({
    this.minHeight,
    this.maxHeight,
    this.normalTextStyle,
    this.highlightTextStyle,
    this.contentParagraphs = const [
      '感谢您信任并使用我们的产品。',
      '当您使用本APP时，请仔细务必仔细阅读、充分理解用户协议和隐私政策各条款，包括但不限于用户注意事项，用户行为规范以及为向您提供服务而收集、使用、存储您个人信息的情况。',
    ],
    this.userAgreementName = '《用户协议》',
    this.privacyPolicyName = '《隐私政策》',
    this.userAgreementUrl = 'https://example.com/agreement',
    this.privacyPolicyUrl = 'https://example.com/privacy',
  });
}

/// 弹窗整体外层配置
class PrivacyDialogConfig {
  final PrivacyHeaderConfig header;
  final PrivacyBodyConfig body;
  final PrivacyFooterConfig footer;
  final PrivacyExitConfirmConfig exitConfirm;
  final Color? backgroundColor;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const PrivacyDialogConfig({
    this.header = const PrivacyHeaderConfig(),
    this.body = const PrivacyBodyConfig(),
    this.footer = const PrivacyFooterConfig(),
    this.exitConfirm = const PrivacyExitConfirmConfig(),
    this.backgroundColor,
    this.width,
    this.padding,
    this.borderRadius,
  });
}

/// 隐私协议全局配置防腐层
class StormyPrivacyConfig {
  static StormyPrivacyConfig? instance;

  final PrivacyDialogConfig uiConfig;
  final Future<bool> Function()? getLocalPrivacyAgreed;
  final Future<void> Function(bool)? saveLocalPrivacyAgreed;

  /// 自定义路由或处理点击协议，如果为空则默认使用 H5 和 modal_bottom_sheet展示
  final void Function(BuildContext context, String url, String title)?
  onUserAgreementTap;
  final void Function(BuildContext context, String url, String title)?
  onPrivacyPolicyTap;

  /// 自定义不同意时的确认退出拦截，返回 true 代表结束，若返回 false 则重发隐私窗
  final Future<bool> Function(BuildContext context)? showExitConfirmDialog;

  const StormyPrivacyConfig({
    this.uiConfig = const PrivacyDialogConfig(),
    this.getLocalPrivacyAgreed,
    this.saveLocalPrivacyAgreed,
    this.onUserAgreementTap,
    this.onPrivacyPolicyTap,
    this.showExitConfirmDialog,
  });

  /// 与另一份 config 合并
  StormyPrivacyConfig copyWith({
    PrivacyDialogConfig? uiConfig,
    Future<bool> Function()? getLocalPrivacyAgreed,
    Future<void> Function(bool)? saveLocalPrivacyAgreed,
    void Function(BuildContext context, String url, String title)?
    onUserAgreementTap,
    void Function(BuildContext context, String url, String title)?
    onPrivacyPolicyTap,
    Future<bool> Function(BuildContext context)? showExitConfirmDialog,
  }) {
    return StormyPrivacyConfig(
      uiConfig: uiConfig ?? this.uiConfig,
      getLocalPrivacyAgreed:
          getLocalPrivacyAgreed ?? this.getLocalPrivacyAgreed,
      saveLocalPrivacyAgreed:
          saveLocalPrivacyAgreed ?? this.saveLocalPrivacyAgreed,
      onUserAgreementTap: onUserAgreementTap ?? this.onUserAgreementTap,
      onPrivacyPolicyTap: onPrivacyPolicyTap ?? this.onPrivacyPolicyTap,
      showExitConfirmDialog:
          showExitConfirmDialog ?? this.showExitConfirmDialog,
    );
  }
}

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({
    super.key,
    required this.config,
    required this.onAgree,
    required this.onDisagree,
  });

  final StormyPrivacyConfig config;
  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  @override
  Widget build(BuildContext context) {
    final ui = config.uiConfig;
    final header = ui.header;
    final body = ui.body;
    final footer = ui.footer;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: ui.width ?? 340.w,
        padding:
            ui.padding ??
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.w),
        decoration: BoxDecoration(
          color: ui.backgroundColor ?? context.theme.background,
          borderRadius: ui.borderRadius ?? BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: context.theme.shadow,
              offset: Offset(0, 4.w),
              blurRadius: 10.r,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 标题
            Text(
              header.title,
              style: TextStyle(
                fontSize: header.fontSize ?? 20.sp,
                fontWeight: header.fontWeight,
                color: header.color ?? context.theme.bodyText,
              ),
            ),
            SizedBox(height: 12.w),
            // 内容文本
            Container(
              width: ui.width != null ? ui.width! - 32.w : 250.w,
              constraints: BoxConstraints(
                minHeight: body.minHeight ?? 0,
                maxHeight: body.maxHeight ?? 210.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...body.contentParagraphs.map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: 8.w),
                        child: Text(
                          p,
                          style:
                              body.normalTextStyle ??
                              TextStyle(
                                fontSize: 14.sp,
                                color: context.theme.bodyText.withAlpha(190),
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.w),
            Container(
              width: ui.width != null ? ui.width! - 32.w : 250.w,
              child: RichText(
                text: TextSpan(
                  style:
                      body.normalTextStyle?.copyWith(
                        fontWeight: FontWeight.w600,
                      ) ??
                      TextStyle(
                        fontSize: 13.sp,
                        color: context.theme.bodyText,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                  children: [
                    const TextSpan(text: '如您同意'),
                    TextSpan(
                      text: body.userAgreementName,
                      style:
                          body.highlightTextStyle ??
                          TextStyle(
                            color: context.theme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (config.onUserAgreementTap != null) {
                            config.onUserAgreementTap!(
                              context,
                              body.userAgreementUrl,
                              body.userAgreementName,
                            );
                          } else {
                            StormyDialog.instance.openH5(
                              context,
                              body.userAgreementUrl,
                              body.userAgreementName,
                            );
                          }
                        },
                    ),
                    const TextSpan(text: '和'),
                    TextSpan(
                      text: body.privacyPolicyName,
                      style:
                          body.highlightTextStyle ??
                          TextStyle(
                            color: context.theme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          if (config.onPrivacyPolicyTap != null) {
                            config.onPrivacyPolicyTap!(
                              context,
                              body.privacyPolicyUrl,
                              body.privacyPolicyName,
                            );
                          } else {
                            StormyDialog.instance.openH5(
                              context,
                              body.privacyPolicyUrl,
                              body.privacyPolicyName,
                            );
                          }
                        },
                    ),
                    const TextSpan(text: '，请点击"同意"开始使用我们的产品和服务。'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.r),
            // 按钮区域
            _buildFooter(context, footer),
            SizedBox(height: 8.r),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, PrivacyFooterConfig footer) {
    if (footer.direction == Axis.vertical) {
      return Column(
        children: [
          _buildButton(
            context,
            text: footer.agreeText,
            color: footer.agreeBgColor ?? context.theme.primary,
            bgDecoration: footer.agreeDecoration,
            textColor: footer.agreeTextColor ?? Colors.white,
            onPressed: onAgree,
            height: footer.buttonHeight,
            radius: footer.buttonRadius,
            fontSize: footer.fontSize,
            fontWeight: footer.fontWeight,
          ),
          SizedBox(height: footer.buttonSpacing.w),
          _buildButton(
            context,
            text: footer.disagreeText,
            color:
                footer.disagreeBgColor ?? const Color(0xFFEFF1F5).withAlpha(90),
            bgDecoration: footer.disagreeDecoration,
            textColor: footer.disagreeTextColor ?? context.theme.bodyText,
            onPressed: onDisagree,
            height: footer.buttonHeight,
            radius: footer.buttonRadius,
            fontSize: footer.fontSize,
            fontWeight: footer.fontWeight,
          ),
        ],
      );
    }
    // horizontal
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            context,
            text: footer.disagreeText,
            color:
                footer.disagreeBgColor ?? const Color(0xFFEFF1F5).withAlpha(90),
            bgDecoration: footer.disagreeDecoration,
            textColor: footer.disagreeTextColor ?? context.theme.bodyText,
            onPressed: onDisagree,
            height: footer.buttonHeight,
            radius: footer.buttonRadius,
            fontSize: footer.fontSize,
            fontWeight: footer.fontWeight,
          ),
        ),
        SizedBox(width: footer.buttonSpacing.w),
        Expanded(
          child: _buildButton(
            context,
            text: footer.agreeText,
            color: footer.agreeBgColor ?? context.theme.primary,
            bgDecoration: footer.agreeDecoration,
            textColor: footer.agreeTextColor ?? Colors.white,
            onPressed: onAgree,
            height: footer.buttonHeight,
            radius: footer.buttonRadius,
            fontSize: footer.fontSize,
            fontWeight: footer.fontWeight,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required Color color,
    BoxDecoration? bgDecoration,
    required Color textColor,
    required VoidCallback onPressed,
    double? height,
    double? radius,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height ?? 48.w,
      child: BaseButton(
        borderRadius: radius ?? 999.r,
        textColor: textColor,
        backgroundColor: color,
        bgDecoration: bgDecoration,
        onPressed: onPressed,
        text: text,
        fontWeight: fontWeight ?? FontWeight.w500,
        fontSize: fontSize ?? 18.sp,
      ),
    );
  }
}
