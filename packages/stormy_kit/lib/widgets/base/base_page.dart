import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' as physics;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../stormy_kit.dart';

/// 基础页面壳体，统一封装页面的返回拦截、滚动控制与 EasyRefresh 集成逻辑。
class BasePage extends StatefulWidget {
  const BasePage({
    super.key,
    required this.child,
    this.lightBackgroundAsset,
    this.darkBackgroundAsset,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.useSafeArea = true,
    this.contentPadding,
    this.fillChildMaxHeight = false,
    this.scrollController,
    this.scrollPhysics,
    this.enableAutoScrollPhysics = true,
    this.canPop = true,
    this.onWillPop,
    this.easyRefreshConfig,
  });

  /// 页面主体内容。
  final Widget child;

  /// 浅色主题下使用的背景图片资源（`assets` 路径）。
  ///
  /// 若当前为浅色主题且不为 null，则优先使用此资源作为整页背景（包含 AppBar 背后区域）。
  final String? lightBackgroundAsset;

  /// 深色主题下使用的背景图片资源（`assets` 路径）。
  ///
  /// 若当前为深色主题且不为 null，则优先使用此资源作为整页背景（包含 AppBar 背后区域）。
  /// 若为空，则在深色主题下会回退使用 [lightBackgroundAsset]。
  final String? darkBackgroundAsset;

  /// 自定义 AppBar。
  final PreferredSizeWidget? appBar;

  /// 悬浮按钮。
  final Widget? floatingActionButton;

  /// 悬浮按钮位置
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// 底部导航栏。
  final Widget? bottomNavigationBar;

  /// 底部弹出层。
  final Widget? bottomSheet;

  /// 左侧抽屉。
  final Widget? drawer;

  /// 右侧抽屉。
  final Widget? endDrawer;

  /// 页面背景色。
  final Color? backgroundColor;

  /// 是否在键盘弹起时自动调整布局。
  final bool? resizeToAvoidBottomInset;

  /// 是否扩展至底部区域。
  final bool extendBody;

  /// 是否让内容延伸到 AppBar 之下。
  final bool extendBodyBehindAppBar;

  /// 是否自动包裹 SafeArea。
  final bool useSafeArea;

  /// 页面内容的统一内边距。
  final EdgeInsetsGeometry? contentPadding;

  /// 是否强制子组件在高度方向撑满可用区域（精确等于可用高度）。
  ///
  /// - 为 `false`（默认）时：对子组件仅施加最小高度约束，使其“至少”占满页面可用高度，
  ///   适用于需要在内容不足一屏时填满，但超出时仍可自然滚动的场景。
  /// - 为 `true` 时：对子组件施加“精确”高度约束（minHeight = maxHeight = 可用高度），
  ///   适用于需要让内部布局（如 `Column` 的 `MainAxisAlignment.spaceBetween`）基于确定高度进行分配的场景。
  final bool fillChildMaxHeight;

  /// 外部自定义的 ScrollController。
  final ScrollController? scrollController;

  /// 外部自定义的滚动物理。
  final ScrollPhysics? scrollPhysics;

  /// 是否根据内容高度自动禁用滚动。
  final bool enableAutoScrollPhysics;

  /// 是否允许直接返回。
  final bool canPop;

  /// 返回拦截回调，返回 true 表示允许退出。
  final FutureOr<bool> Function()? onWillPop;

  /// EasyRefresh 配置，不传则不会启用下拉刷新。
  final EasyRefreshConfig? easyRefreshConfig;

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  double? _contentHeight;
  double? _viewportHeight;
  bool _sizeChangeCallbackScheduled = false;

  @override
  Widget build(BuildContext context) {
    final bool hasWillPop = widget.onWillPop != null;
    final bool effectiveCanPop = hasWillPop ? false : widget.canPop;

    // 根据当前主题选择对应的背景图片资源（整页固定背景，不随内容滚动）
    final Brightness brightness = Theme.of(context).brightness;
    final String? backgroundAsset = brightness == Brightness.dark
        ? (widget.darkBackgroundAsset ?? widget.lightBackgroundAsset)
        : widget.lightBackgroundAsset;

    Widget scaffold = Scaffold(
      backgroundColor: backgroundAsset != null
          ? Colors.transparent
          : widget.backgroundColor ??
                StormyTheme.currentVariant.scaffoldBackground,
      appBar: widget.appBar,
      extendBody: widget.extendBody,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
      bottomSheet: widget.bottomSheet,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 视口高度（已排除 AppBar 高度）
          _viewportHeight = constraints.maxHeight;
          // 获取SafeArea信息
          final MediaQueryData mediaQuery = MediaQuery.of(context);

          // 根据是否需要 SafeArea 与是否延伸到 AppBar 之下，计算需要应用的安全区内边距
          final EdgeInsets mediaPadding = MediaQuery.of(context).padding;
          // 获取顶部安全区域高度
          final double topSafeInset =
              widget.useSafeArea && widget.extendBodyBehindAppBar
              ? mediaPadding.top
              : 0.0;
          // 获取底部安全区域高度
          final double bottomSafeInset = widget.useSafeArea
              ? mediaQuery.viewInsets.bottom
              : 0.0;

          // 实际可用高度（排除安全区域后），用于内容最小高度约束
          final double availableHeight =
              (constraints.maxHeight - topSafeInset - bottomSafeInset).clamp(
                0.0,
                constraints.maxHeight,
              );
          // 实际可用高度（排除安全区域后），用于内容最大高度约束
          final double maxHeight =
              (constraints.maxHeight - topSafeInset - bottomSafeInset).clamp(
                0.0,
                1.sh,
              );
          // 组合内容额外内边距（安全区 + 外部传入的 contentPadding）
          final EdgeInsetsGeometry combinedPadding = (EdgeInsets.only(
            top: topSafeInset,
            bottom: bottomSafeInset,
          )).add(widget.contentPadding ?? EdgeInsets.zero);
          // 构造内部内容：先应用 Padding，再按需使用最小/精确高度约束，保证在安全区内正确填充可用高度
          final BoxConstraints contentConstraints = widget.fillChildMaxHeight
              ? BoxConstraints(minHeight: maxHeight, maxHeight: maxHeight)
              : BoxConstraints(minHeight: availableHeight);
          final Widget innerContent = ConstrainedBox(
            constraints: contentConstraints,
            child: Padding(padding: combinedPadding, child: widget.child),
          );

          // 当 fillChildMaxHeight 为 true 时，内容需要固定高度，不应该使用 SingleChildScrollView
          // 因为 SingleChildScrollView 会提供无界约束，导致内部使用 Expanded 的组件无法工作
          if (widget.fillChildMaxHeight) {
            return innerContent;
          }

          // 交给测量组件，驱动自动滚动物理计算
          final Widget measuredChild = _MeasuredChild(
            onSizeChanged: _handleContentSizeChanged,
            child: innerContent,
          );
          final ScrollPhysics effectivePhysics = _resolveScrollPhysics();
          if (widget.easyRefreshConfig != null) {
            return widget.easyRefreshConfig!.build(
              measuredChild: measuredChild,
              scrollController: widget.scrollController,
              physics: effectivePhysics,
            );
          }
          return SingleChildScrollView(
            controller: widget.scrollController,
            physics: effectivePhysics,
            child: measuredChild,
          );
        },
      ),
    );

    if (backgroundAsset != null) {
      scaffold = Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: scaffold,
      );
    }

    return PopScope(
      canPop: effectiveCanPop,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        if (!mounted) {
          return;
        }
        _invokeWillPop();
      },
      child: scaffold,
    );
  }

  /// 计算最终滚动物理。
  ScrollPhysics _resolveScrollPhysics() {
    final ScrollPhysics base =
        widget.scrollPhysics ?? const ClampingScrollPhysics();
    if (!widget.enableAutoScrollPhysics) {
      return base;
    }
    if (_contentHeight == null || _viewportHeight == null) {
      return base;
    }
    if (_contentHeight! <= _viewportHeight!) {
      return const NeverScrollableScrollPhysics();
    }
    return base;
  }

  void _handleContentSizeChanged(Size size) {
    final double newHeight = size.height;
    if (_contentHeight != null && (_contentHeight! - newHeight).abs() < 0.5) {
      return;
    }
    // 防止重复注册回调
    if (_sizeChangeCallbackScheduled) {
      return;
    }
    _sizeChangeCallbackScheduled = true;
    // 使用 SchedulerBinding 确保在布局完全完成后才更新状态
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sizeChangeCallbackScheduled = false;
      if (!mounted) return;
      setState(() {
        _contentHeight = newHeight;
      });
    });
  }

  void _invokeWillPop() {
    final callback = widget.onWillPop;
    if (callback == null) {
      return;
    }
    Future.microtask(() async {
      final result = await callback();
      if (!mounted || !result) {
        return;
      }
      if (!widget.canPop && widget.onWillPop != null) {
        // 当通过 onWillPop 手动放行时，由我们负责关闭页面。
        Navigator.of(context).maybePop();
        return;
      }
      Navigator.of(context).maybePop();
    });
  }
}

/// EasyRefresh 的参数封装，便于按需开启刷新能力。
class EasyRefreshConfig {
  const EasyRefreshConfig({
    this.controller,
    this.header,
    this.footer,
    this.onRefresh,
    this.onLoad,
    this.notRefreshHeader,
    this.notLoadFooter,
    this.simultaneously,
    this.canRefreshAfterNoMore,
    this.canLoadAfterNoMore,
    this.resetAfterRefresh,
    this.refreshOnStart,
    this.refreshOnStartHeader,
    this.callRefreshOverOffset,
    this.callLoadOverOffset,
    this.spring,
    this.frictionFactor,
    this.scrollBehaviorBuilder,
    this.triggerAxis,
    this.scrollController,
  });

  /// EasyRefresh 控制器。
  final EasyRefreshController? controller;

  /// 自定义 Header。
  final Header? header;

  /// 自定义 Footer。
  final Footer? footer;

  /// 下拉刷新回调。
  final FutureOr Function()? onRefresh;

  /// 上拉加载回调。
  final FutureOr Function()? onLoad;

  /// 无刷新能力时的占位 Header。
  final NotRefreshHeader? notRefreshHeader;

  /// 无加载能力时的占位 Footer。
  final NotLoadFooter? notLoadFooter;

  /// 是否允许同时执行刷新与加载。
  final bool? simultaneously;

  /// 是否在无更多数据后仍可刷新。
  final bool? canRefreshAfterNoMore;

  /// 是否在无更多数据后仍可加载。
  final bool? canLoadAfterNoMore;

  /// 刷新结束后是否重置加载状态。
  final bool? resetAfterRefresh;

  /// 是否在初始化后自动刷新。
  final bool? refreshOnStart;

  /// 自动刷新时使用的 Header。
  final Header? refreshOnStartHeader;

  /// 调用刷新时的额外偏移。
  final double? callRefreshOverOffset;

  /// 调用加载时的额外偏移。
  final double? callLoadOverOffset;

  /// 下拉回弹的物理配置。
  final physics.SpringDescription? spring;

  /// 越界时的阻尼系数。
  final FrictionFactor? frictionFactor;

  /// 自定义滚动行为。
  final ERScrollBehaviorBuilder? scrollBehaviorBuilder;

  /// 触发刷新的方向。
  final Axis? triggerAxis;

  /// EasyRefresh 关联的滚动控制器。
  final ScrollController? scrollController;

  /// 生成 EasyRefresh 实例。
  Widget build({
    required Widget measuredChild,
    ScrollController? scrollController,
    ScrollPhysics? physics,
  }) {
    return EasyRefresh.builder(
      controller: controller,
      header: header,
      footer: footer,
      onRefresh: onRefresh,
      onLoad: onLoad,
      notRefreshHeader: notRefreshHeader,
      notLoadFooter: notLoadFooter,
      simultaneously: simultaneously ?? false,
      canRefreshAfterNoMore: canRefreshAfterNoMore ?? false,
      canLoadAfterNoMore: canLoadAfterNoMore ?? false,
      resetAfterRefresh: resetAfterRefresh ?? true,
      refreshOnStart: refreshOnStart ?? false,
      refreshOnStartHeader: refreshOnStartHeader,
      callRefreshOverOffset: callRefreshOverOffset ?? 20,
      callLoadOverOffset: callLoadOverOffset ?? 20,
      spring: spring,
      frictionFactor: frictionFactor,
      scrollBehaviorBuilder: scrollBehaviorBuilder,
      triggerAxis: triggerAxis,
      scrollController: this.scrollController ?? scrollController,
      childBuilder: (context, refreshPhysics) {
        // 优先使用 refreshPhysics 以确保下拉刷新功能正常工作
        final ScrollPhysics effectivePhysics = refreshPhysics;
        final ScrollController? effectiveController =
            this.scrollController ?? scrollController;
        return SingleChildScrollView(
          controller: effectiveController,
          physics: effectivePhysics,
          primary: effectiveController == null,
          child: measuredChild,
        );
      },
    );
  }
}

/// 监听页面尺寸变化的工具组件。
class _MeasuredChild extends SingleChildRenderObjectWidget {
  const _MeasuredChild({required this.onSizeChanged, required super.child});

  final ValueChanged<Size> onSizeChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasuredRenderBox(onSizeChanged);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasuredRenderBox renderObject,
  ) {
    renderObject.onSizeChanged = onSizeChanged;
  }
}

class _MeasuredRenderBox extends RenderProxyBox {
  _MeasuredRenderBox(this.onSizeChanged);

  ValueChanged<Size> onSizeChanged;
  Size? _lastReportedSize;
  bool _callbackScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    // 只在尺寸真正改变且尚未注册回调时才注册
    if (!hasSize) {
      return;
    }
    final Size currentSize = size;
    if (_lastReportedSize == currentSize) {
      return;
    }
    // 防止重复注册回调
    if (_callbackScheduled) {
      return;
    }
    _callbackScheduled = true;
    // 使用 SchedulerBinding 确保在布局完全完成后才执行回调
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _callbackScheduled = false;
      if (!hasSize) {
        return;
      }
      final Size currentSize = size;
      if (_lastReportedSize == currentSize) {
        return;
      }
      _lastReportedSize = currentSize;
      onSizeChanged(currentSize);
    });
  }
}

/// 底部填充区域(自动计算)
class BaseBottomPadding extends StatelessWidget {
  const BaseBottomPadding({super.key, this.height});
  final double? height;
  @override
  Widget build(BuildContext context) {
    /// 获取ios底部安全区域高度
    return SizedBox(height: (height ?? 12.r) + ScreenUtil().bottomBarHeight);
  }
}
