import 'package:flutter/material.dart';

/// Indicator 对齐方式
enum IndicatorAlignment {
  /// 左对齐：indicator 与 label 左边对齐
  start,

  /// 居中对齐：indicator 在 label 下方居中（默认）
  center,

  /// 右对齐：indicator 与 label 右边对齐
  end,
}

/// 自定义 TabBar 组件
///
/// 特性：
/// - 可滚动：当 Tab 总宽度超过可用空间时，支持横向滚动
/// - 从左开始排列：Tab 从左侧开始排列，不居中
/// - Tab 宽度自适应：每个 Tab 的宽度根据标题文本自动调整，不均分可用空间
/// - 右侧留白：如果右边还有空间，则留白，不填充
/// - Indicator 对齐：支持左对齐、居中对齐、右对齐三种方式
class BaseTabBar extends StatefulWidget implements PreferredSizeWidget {
  /// TabController，用于控制 Tab 的选中状态
  final TabController controller;

  /// Tab 标题列表
  final List<String> tabs;

  /// 选中的 Tab 文字颜色
  final Color? labelColor;

  /// 未选中的 Tab 文字颜色
  final Color? unselectedLabelColor;

  /// 选中的 Tab 文字样式
  final TextStyle? labelStyle;

  /// 未选中的 Tab 文字样式
  final TextStyle? unselectedLabelStyle;

  /// Tab 的内边距
  final EdgeInsetsGeometry? tabPadding;

  /// Tab 之间的间距
  final double? tabSpacing;

  /// 指示器颜色（下划线颜色）
  final Color? indicatorColor;

  /// 指示器高度
  final double? indicatorHeight;

  /// 指示器宽度（如果为 null，则自适应 Tab 宽度）
  final double? indicatorWidth;

  /// 指示器padding
  final EdgeInsetsGeometry? indicatorPadding;

  /// 指示器对齐方式
  /// - IndicatorAlignment.start: indicator 与 label 左边对齐
  /// - IndicatorAlignment.center: indicator 在 label 下方居中（默认）
  /// - IndicatorAlignment.end: indicator 与 label 右边对齐
  final IndicatorAlignment indicatorAlignment;

  /// 背景颜色
  final Color? backgroundColor;

  /// TabBar 的高度
  final double? height;

  /// 可选外部滚动控制器，若为 null 则内部创建并管理
  final ScrollController? scrollController;

  /// 是否启用平滑指示器（基于 TabController.animation 插值）
  /// 在低端设备上可以将此项设为 false，以关闭精确监听并使用原始 index 驱动的指示器更新。
  final bool smoothIndicator;

  /// Tab 切换时的回调，参数为当前选中 tab 的索引
  final ValueChanged<int>? onChange;

  BaseTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.smoothIndicator = true,
    this.onChange,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.tabPadding,
    this.tabSpacing,
    this.indicatorColor,
    this.indicatorHeight,
    this.indicatorWidth,
    this.indicatorPadding,
    this.indicatorAlignment = IndicatorAlignment.center,
    this.backgroundColor,
    this.height,
    this.scrollController,
  }) : assert(tabs.isNotEmpty, 'tabs must not be empty');

  @override
  Size get preferredSize => Size.fromHeight(height ?? 48.0);

  @override
  State<BaseTabBar> createState() => _BaseTabBarState();
}

class _BaseTabBarState extends State<BaseTabBar> {
  late final ScrollController _internalScrollController;
  bool _ownsScrollController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _internalScrollController = widget.scrollController!;
      _ownsScrollController = false;
    } else {
      _internalScrollController = ScrollController();
      _ownsScrollController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsScrollController) {
      _internalScrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultLabelColor = widget.labelColor ?? theme.primaryColor;
    final defaultUnselectedLabelColor =
        widget.unselectedLabelColor ?? theme.unselectedWidgetColor;
    final defaultLabelStyle =
        widget.labelStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final defaultUnselectedLabelStyle =
        widget.unselectedLabelStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w400);
    final defaultTabPadding =
        widget.tabPadding ?? const EdgeInsets.symmetric(horizontal: 16.0);
    final defaultTabSpacing = widget.tabSpacing ?? 0.0;
    final defaultIndicatorColor = widget.indicatorColor ?? theme.indicatorColor;
    final defaultIndicatorHeight = widget.indicatorHeight ?? 2.0;

    return Container(
      color: widget.backgroundColor,
      height: widget.preferredSize.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          return SingleChildScrollView(
            controller: _internalScrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            child: _TabBarContent(
              controller: widget.controller,
              tabs: widget.tabs,
              labelColor: defaultLabelColor,
              unselectedLabelColor: defaultUnselectedLabelColor,
              labelStyle: defaultLabelStyle,
              unselectedLabelStyle: defaultUnselectedLabelStyle,
              tabPadding: defaultTabPadding,
              tabSpacing: defaultTabSpacing,
              indicatorColor: defaultIndicatorColor,
              indicatorHeight: defaultIndicatorHeight,
              indicatorWidth: widget.indicatorWidth,
              indicatorPadding: widget.indicatorPadding,
              indicatorAlignment: widget.indicatorAlignment,
              scrollController: _internalScrollController,
              viewportWidth: viewportWidth,
              smoothIndicator: widget.smoothIndicator,
              textDirection: Directionality.of(context),
            ),
          );
        },
      ),
    );
  }
}

class _TabBarContent extends StatefulWidget {
  final TabController controller;
  final List<String> tabs;
  final Color labelColor;
  final Color unselectedLabelColor;
  final TextStyle labelStyle;
  final TextStyle unselectedLabelStyle;
  final EdgeInsetsGeometry tabPadding;
  final double tabSpacing;
  final Color indicatorColor;
  final double indicatorHeight;
  final double? indicatorWidth;
  final EdgeInsetsGeometry? indicatorPadding;
  final IndicatorAlignment indicatorAlignment;
  final ScrollController scrollController;
  final double viewportWidth;
  final bool smoothIndicator;
  final TextDirection? textDirection;
  final ValueChanged<int>? onChange;
  const _TabBarContent({
    required this.controller,
    required this.tabs,
    required this.labelColor,
    required this.unselectedLabelColor,
    required this.labelStyle,
    required this.unselectedLabelStyle,
    required this.tabPadding,
    required this.tabSpacing,
    required this.indicatorColor,
    required this.indicatorHeight,
    this.indicatorWidth,
    this.indicatorPadding,
    required this.indicatorAlignment,
    required this.scrollController,
    required this.viewportWidth,
    required this.smoothIndicator,
    this.textDirection,
    this.onChange,
  });

  @override
  State<_TabBarContent> createState() => _TabBarContentState();
}

class _TabBarContentState extends State<_TabBarContent> {
  final Map<int, GlobalKey> _tabKeys = {};
  final Map<int, double> _tabWidths = {};
  final Map<int, double> _tabPositions = {};
  final Map<int, double> _textWidths = {};
  final Map<int, double> _textPositions = {};
  int _selectedIndex = 0;
  bool _didInitialScroll = false;
  // 驱动平滑指示器的值（当 smoothIndicator == true 时由 controller.animation 更新）
  late final ValueNotifier<double> _indicatorValue;
  // 避免每帧都重复测量
  bool _needsMeasure = true;
  // 节流：上次触发滚动的时间戳（毫秒）
  int _lastScrollTime = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.index;
    widget.controller.addListener(_onTabChanged);

    _indicatorValue = ValueNotifier<double>(widget.controller.index.toDouble());
    // 仅在开启平滑指示器时监听 animation（低端设备可关闭）
    if (widget.smoothIndicator) {
      widget.controller.animation?.addListener(_onAnimationTick);
    }

    // 初始化所有 Tab 的 Key
    for (int i = 0; i < widget.tabs.length; i++) {
      _tabKeys[i] = GlobalKey();
    }
  }

  @override
  void dispose() {
    if (widget.smoothIndicator) {
      widget.controller.animation?.removeListener(_onAnimationTick);
    }
    _indicatorValue.dispose();
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onAnimationTick() {
    if (!mounted) return;
    final anim = widget.controller.animation;
    if (anim == null) return;
    // 直接更新 notifier，让指示器局部重建
    _indicatorValue.value = anim.value;
    // 在动画过程中尝试更及时地滚动 TabBar，使选中项居中（有限节流）
    _maybeScrollDuringAnimation(anim.value);
  }

  void _maybeScrollDuringAnimation(double value) {
    // 节流：至少间隔 50ms
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollTime < 50) return;
    _lastScrollTime = now;

    final maxIndex = widget.tabs.length - 1;
    final clamped = value.clamp(0.0, maxIndex.toDouble());
    final int floorIndex = clamped.floor();
    final int ceilIndex = (floorIndex < maxIndex)
        ? (floorIndex + 1)
        : floorIndex;
    final double t = clamped - floorIndex.toDouble();

    if (!_textWidths.containsKey(floorIndex) ||
        !_textPositions.containsKey(floorIndex)) {
      return;
    }

    final double leftFloor = _textPositions[floorIndex]!;
    final double leftCeil = _textPositions[ceilIndex] ?? leftFloor;
    final double widthFloor = _textWidths[floorIndex] ?? 0.0;
    final double widthCeil = _textWidths[ceilIndex] ?? widthFloor;

    final double left = leftFloor + (leftCeil - leftFloor) * t;
    final double interpWidth = widthFloor + (widthCeil - widthFloor) * t;
    final double centerOfTab = left + interpWidth / 2;
    final double viewportCenter = widget.viewportWidth / 2;
    double targetOffset = centerOfTab - viewportCenter;

    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final maxExtent = controller.position.maxScrollExtent;
    if (targetOffset < 0) targetOffset = 0;
    if (targetOffset > maxExtent) targetOffset = maxExtent;

    final currentOffset = controller.offset;
    // 只在目标偏移与当前偏移差异较大时触发动画，避免频繁小幅滚动
    if ((targetOffset - currentOffset).abs() < 1.0) return;

    // 使用短时长动画使滚动更及时平滑
    controller.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 120),
      curve: Curves.linear,
    );
  }

  void _onTabChanged() {
    if (!mounted) return;
    final newIndex = widget.controller.index;
    if (_selectedIndex == newIndex) return;
    setState(() {
      _selectedIndex = newIndex;
    });
    // 调用外部回调
    widget.onChange?.call(newIndex);
    // 尝试滚动到居中（如果已测量）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeScrollToSelected();
    });
  }

  EdgeInsetsGeometry _getTabPadding(int index) {
    if (index == 0) {
      // 第一个 Tab：左边 padding 为 0，保持其他 padding
      final padding = widget.tabPadding;
      if (padding is EdgeInsets) {
        return EdgeInsets.only(
          left: 0,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        );
      } else if (padding is EdgeInsetsDirectional) {
        return EdgeInsetsDirectional.only(
          start: 0,
          top: padding.top,
          end: padding.end,
          bottom: padding.bottom,
        );
      }
      // 对于其他类型的 EdgeInsetsGeometry，尝试转换为 EdgeInsets
      final resolved = padding.resolve(TextDirection.ltr);
      return EdgeInsets.only(
        left: 0,
        top: resolved.top,
        right: resolved.right,
        bottom: resolved.bottom,
      );
    }
    return widget.tabPadding;
  }

  void _measureTabs() {
    double currentPosition = 0;
    for (int i = 0; i < widget.tabs.length; i++) {
      final key = _tabKeys[i];
      if (key?.currentContext != null) {
        final RenderBox? renderBox =
            key!.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final width = renderBox.size.width;
          if (_tabWidths[i] != width || _tabPositions[i] != currentPosition) {
            setState(() {
              _tabWidths[i] = width;
              _tabPositions[i] = currentPosition;
            });
          }

          // 计算文本宽度和位置
          final tabPadding = _getTabPadding(i);
          final EdgeInsets resolvedPadding = tabPadding.resolve(
            widget.textDirection ?? TextDirection.ltr,
          );

          // 使用 TextPainter 测量文本宽度
          final textPainter = TextPainter(
            text: TextSpan(text: widget.tabs[i], style: widget.labelStyle),
            textDirection: widget.textDirection ?? TextDirection.ltr,
          );
          textPainter.layout();

          final textWidth = textPainter.width;
          final textLeft = currentPosition + resolvedPadding.left;

          if (_textWidths[i] != textWidth || _textPositions[i] != textLeft) {
            setState(() {
              _textWidths[i] = textWidth;
              _textPositions[i] = textLeft;
            });
          }

          currentPosition += width;
          if (i < widget.tabs.length - 1) {
            currentPosition += widget.tabSpacing;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 测量所有 Tab 的宽度和位置（仅在必要时执行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_needsMeasure || _tabWidths.length != widget.tabs.length) {
        _measureTabs();
        _needsMeasure = false;
      }
      // 在首次测量后尝试将当前选中项居中
      if (!_didInitialScroll) {
        _didInitialScroll = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeScrollToSelected();
        });
      }
    });

    return Stack(
      clipBehavior: Clip.none,
      alignment: AlignmentDirectional.centerStart,
      children: [
        // Tab 内容：如果启用了平滑指示器，则根据动画值动态计算每个 Tab 的激活度并重建；否则按离散选中渲染
        if (widget.smoothIndicator)
          ValueListenableBuilder<double>(
            valueListenable: _indicatorValue,
            builder: (context, value, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: [
                  for (int i = 0; i < widget.tabs.length; i++) ...[
                    if (i > 0) SizedBox(width: widget.tabSpacing),
                    _TabItem(
                      key: _tabKeys[i],
                      index: i,
                      text: widget.tabs[i],
                      // 激活度：当动画值靠近该索引时接近 1；距离 >=1 时为 0
                      activePercent: (1.0 - (value - i).abs()).clamp(0.0, 1.0),
                      labelColor: widget.labelColor,
                      unselectedLabelColor: widget.unselectedLabelColor,
                      labelStyle: widget.labelStyle,
                      unselectedLabelStyle: widget.unselectedLabelStyle,
                      tabPadding: _getTabPadding(i),
                      onTap: () {
                        if (widget.controller.index != i) {
                          widget.controller.animateTo(i);
                        }
                      },
                    ),
                  ],
                ],
              );
            },
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: [
              for (int i = 0; i < widget.tabs.length; i++) ...[
                if (i > 0) SizedBox(width: widget.tabSpacing),
                _TabItem(
                  key: _tabKeys[i],
                  index: i,
                  text: widget.tabs[i],
                  isSelected: i == _selectedIndex,
                  labelColor: widget.labelColor,
                  unselectedLabelColor: widget.unselectedLabelColor,
                  labelStyle: widget.labelStyle,
                  unselectedLabelStyle: widget.unselectedLabelStyle,
                  tabPadding: _getTabPadding(i),
                  onTap: () {
                    if (widget.controller.index != i) {
                      widget.controller.animateTo(i);
                    }
                  },
                ),
              ],
            ],
          ),
        // 指示器：当开启平滑指示器时，使用动画值插值位置与宽度；否则回退到根据 _selectedIndex 的离散渲染
        if (widget.smoothIndicator)
          ValueListenableBuilder<double>(
            valueListenable: _indicatorValue,
            builder: (context, value, child) {
              final maxIndex = widget.tabs.length - 1;
              final clamped = value.clamp(0.0, maxIndex.toDouble());
              final int floorIndex = clamped.floor();
              final int ceilIndex = (floorIndex < maxIndex)
                  ? (floorIndex + 1)
                  : floorIndex;
              final double t = clamped - floorIndex.toDouble();

              if (!_textWidths.containsKey(floorIndex) ||
                  !_textPositions.containsKey(floorIndex)) {
                return const SizedBox.shrink();
              }

              final double leftFloor = _textPositions[floorIndex]!;
              final double leftCeil = _textPositions[ceilIndex] ?? leftFloor;
              final double widthFloor = _textWidths[floorIndex] ?? 0.0;
              final double widthCeil = _textWidths[ceilIndex] ?? widthFloor;

              final double textLeft = leftFloor + (leftCeil - leftFloor) * t;
              final double textWidth =
                  widthFloor + (widthCeil - widthFloor) * t;
              final double indicatorWidth = widget.indicatorWidth ?? textWidth;

              // 解析 indicatorPadding 为 EdgeInsets，默认为 zero
              final EdgeInsets indicatorPadding =
                  (widget.indicatorPadding ?? EdgeInsets.zero).resolve(
                    widget.textDirection ?? TextDirection.ltr,
                  );

              final double finalIndicatorWidth =
                  indicatorWidth - indicatorPadding.horizontal;
              final double indicatorLeft = _calculateIndicatorLeft(
                textLeft,
                textWidth,
                finalIndicatorWidth,
              );

              return Positioned(
                left: indicatorLeft + indicatorPadding.left,
                bottom: indicatorPadding.bottom,
                child: Container(
                  width: finalIndicatorWidth,
                  height: widget.indicatorHeight,
                  color: widget.indicatorColor,
                ),
              );
            },
          )
        else if (_textWidths.containsKey(_selectedIndex) &&
            _textPositions.containsKey(_selectedIndex))
          // 解析 indicatorPadding 为 EdgeInsets，默认为 zero
          () {
            final EdgeInsets indicatorPadding =
                (widget.indicatorPadding ?? EdgeInsets.zero).resolve(
                  widget.textDirection ?? TextDirection.ltr,
                );

            final double textLeft = _textPositions[_selectedIndex]!;
            final double textWidth = _textWidths[_selectedIndex]!;
            final double indicatorWidth = widget.indicatorWidth ?? textWidth;
            final double finalIndicatorWidth =
                indicatorWidth - indicatorPadding.horizontal;
            final double indicatorLeft = _calculateIndicatorLeft(
              textLeft,
              textWidth,
              finalIndicatorWidth,
            );

            return Positioned(
              left: indicatorLeft + indicatorPadding.left,
              bottom: indicatorPadding.bottom,
              child: Container(
                width: finalIndicatorWidth,
                height: widget.indicatorHeight,
                color: widget.indicatorColor,
              ),
            );
          }(),
      ],
    );
  }

  /// 根据对齐方式计算 indicator 的 left 位置
  double _calculateIndicatorLeft(
    double textLeft,
    double textWidth,
    double indicatorWidth,
  ) {
    switch (widget.indicatorAlignment) {
      case IndicatorAlignment.start:
        return textLeft;
      case IndicatorAlignment.center:
        return textLeft + (textWidth - indicatorWidth) / 2;
      case IndicatorAlignment.end:
        return textLeft + textWidth - indicatorWidth;
    }
  }

  void _maybeScrollToSelected() {
    final index = _selectedIndex;
    if (!_tabWidths.containsKey(index) || !_tabPositions.containsKey(index)) {
      return;
    }
    _scrollToCenter(index);
  }

  void _scrollToCenter(int index) {
    final widths = _tabWidths;
    final positions = _tabPositions;
    if (!widths.containsKey(index) || !positions.containsKey(index)) return;

    final tabWidth = widths[index]!;
    final tabLeft = positions[index]!;
    final centerOfTab = tabLeft + tabWidth / 2;
    final viewportCenter = widget.viewportWidth / 2;
    double targetOffset = centerOfTab - viewportCenter;

    final controller = widget.scrollController;
    if (!controller.hasClients) {
      // 延迟到下一帧重试
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToCenter(index),
      );
      return;
    }

    final maxExtent = controller.position.maxScrollExtent;
    if (targetOffset < 0) targetOffset = 0;
    if (targetOffset > maxExtent) targetOffset = maxExtent;

    controller.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }
}

class _TabItem extends StatelessWidget {
  final int index;
  final String text;
  final bool? isSelected;

  /// 激活度（0.0 - 1.0），优先于 isSelected，当 smoothIndicator 开启时会传入该值
  final double activePercent;
  final Color labelColor;
  final Color unselectedLabelColor;
  final TextStyle labelStyle;
  final TextStyle unselectedLabelStyle;
  final EdgeInsetsGeometry tabPadding;
  final VoidCallback onTap;

  const _TabItem({
    super.key,
    required this.index,
    required this.text,
    this.isSelected,
    this.activePercent = 0.0,
    required this.labelColor,
    required this.unselectedLabelColor,
    required this.labelStyle,
    required this.unselectedLabelStyle,
    required this.tabPadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 计算激活度：如果传入 activePercent 则优先使用，否则使用 isSelected 做离散值
    final double active = (activePercent != 0.0)
        ? activePercent.clamp(0.0, 1.0)
        : ((isSelected ?? false) ? 1.0 : 0.0);

    // 使用 TextStyle.lerp 在激活度上进行插值，以实现颜色/样式渐变
    final TextStyle fromStyle = unselectedLabelStyle.color != null
        ? unselectedLabelStyle
        : unselectedLabelStyle.copyWith(color: unselectedLabelColor);
    final TextStyle toStyle = labelStyle.color != null
        ? labelStyle
        : labelStyle.copyWith(color: labelColor);
    final textStyle = TextStyle.lerp(fromStyle, toStyle, active) ?? toStyle;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: tabPadding,
        child: Text(text, style: textStyle),
      ),
    );
  }
}
