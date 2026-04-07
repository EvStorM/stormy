import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../stormy_kit.dart';

class BaseAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BaseAppBar({
    super.key,
    this.title = '',
    this.backIcon,
    this.titleWidget,
    this.actions,
    this.backgroundColor,
    // this.leading,
    this.leftWidgets,
  });
  final String title;
  final String? backIcon;
  final List<Widget>? actions;
  final Widget? titleWidget;
  final Color? backgroundColor;
  // final Widget? leading;

  /// 左侧元素列表（推荐使用此方案，比 leading 更灵活）
  /// 可以放置多个元素，自动处理间距和对齐
  final List<Widget>? leftWidgets;
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor:
          backgroundColor ?? StormyTheme.currentVariant.scaffoldBackground,
      elevation: 0,
      actions: actions,
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      // systemOverlayStyle: StatusBarStyle.darkContent,
      flexibleSpace: FlexibleSpaceLayout(
        title:
            titleWidget ??
            Text(
              title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
        leftWidgets: leftWidgets?.isNotEmpty ?? false
            ? leftWidgets!
            : [
                (Navigator.canPop(context) &&
                        (StormyConfigAccessor.assets?.backIcon.isNotEmpty ??
                            false)
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Image.asset(
                          backIcon ?? StormyConfigAccessor.assets!.backIcon,
                          width: 24.r,
                          height: 24.r,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                      )
                    : const SizedBox.shrink()),
              ],
      ),
    );
  }

  // @override
  // Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight - 12);
}

/// 使用 flexibleSpace 实现的灵活布局
/// 优点：
/// 1. 可以放置多个左侧元素
/// 2. 完全控制布局和对齐
/// 3. 保持 AppBar 的标准行为和样式
/// 4. 支持响应式布局
/// 5. 左侧元素自动占满，title 始终居中
class FlexibleSpaceLayout extends StatelessWidget {
  const FlexibleSpaceLayout({
    super.key,
    required this.title,
    required this.leftWidgets,
  });

  final Widget? title;
  final List<Widget> leftWidgets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // 左侧元素区域（从左边开始，自动扩展）
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 8.r),
                ...leftWidgets
                    .expand((widget) => [widget, SizedBox(width: 4.r)])
                    .toList()
                  ..removeLast(), // 移除最后一个间距
              ],
            ),
          ),
          // 标题区域（在整个 flexibleSpace 区域居中）
          if (title != null) Positioned.fill(child: Center(child: title!)),
        ],
      ),
    );
  }
}
