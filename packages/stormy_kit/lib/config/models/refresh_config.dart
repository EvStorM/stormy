import 'package:flutter/material.dart';

/// 刷新文本配置
/// 用于配置下拉刷新和上拉加载的相关文本内容
class StormyRefreshTextConfig {
  const StormyRefreshTextConfig({
    this.loading,
    this.releaseToLoad,
    this.pullToLoad,
    this.loadSuccess,
    this.loadSuccessMessage,
    this.loadFailed,
    this.noMoreData,
    this.lastUpdated,
  });

  /// 加载中
  final String? loading;

  /// 释放加载
  final String? releaseToLoad;

  /// 下拉加载
  final String? pullToLoad;

  /// 加载成功
  final String? loadSuccess;

  /// 加载成功消息
  final String? loadSuccessMessage;

  /// 加载失败
  final String? loadFailed;

  /// 没有更多数据
  final String? noMoreData;

  /// 上次更新
  final String? lastUpdated;

  /// 创建默认中文配置
  factory StormyRefreshTextConfig.zhCN() {
    return const StormyRefreshTextConfig(
      loading: '加载中...',
      releaseToLoad: '释放加载',
      pullToLoad: '下拉加载',
      loadSuccess: '加载成功',
      loadSuccessMessage: '加载完成',
      loadFailed: '加载失败',
      noMoreData: '没有更多了',
      lastUpdated: '上次更新：%T',
    );
  }

  /// 创建默认英文配置
  factory StormyRefreshTextConfig.enUS() {
    return const StormyRefreshTextConfig(
      loading: 'Loading...',
      releaseToLoad: 'Release to load',
      pullToLoad: 'Pull to load',
      loadSuccess: 'Load success',
      loadSuccessMessage: 'Load completed',
      loadFailed: 'Load failed',
      noMoreData: 'No more data',
      lastUpdated: 'Last updated: %T',
    );
  }

  /// 复制并修改配置
  StormyRefreshTextConfig copyWith({
    String? loading,
    String? releaseToLoad,
    String? pullToLoad,
    String? loadSuccess,
    String? loadSuccessMessage,
    String? loadFailed,
    String? noMoreData,
    String? lastUpdated,
  }) {
    return StormyRefreshTextConfig(
      loading: loading ?? this.loading,
      releaseToLoad: releaseToLoad ?? this.releaseToLoad,
      pullToLoad: pullToLoad ?? this.pullToLoad,
      loadSuccess: loadSuccess ?? this.loadSuccess,
      loadSuccessMessage: loadSuccessMessage ?? this.loadSuccessMessage,
      loadFailed: loadFailed ?? this.loadFailed,
      noMoreData: noMoreData ?? this.noMoreData,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Refresh Config - 刷新配置
/// 用于配置下拉刷新和上拉加载的相关参数
class StormyRefreshConfig {
  /// 触发刷新的偏移量
  final double triggerOffset;

  /// 动画处理时长
  final Duration processedDuration;

  /// 图标尺寸
  final double iconDimension;

  /// 间距
  final double spacing;

  /// 文本样式
  final TextStyle? textStyle;

  /// 提示消息样式
  final TextStyle? messageStyle;

  /// 各种状态下的提示文本（如果有专门定义优先取这里，如果不指定则使用 textConfig）
  final StormyRefreshStateTexts? stateTexts;

  /// 是否显示提示消息
  final bool showMessage;

  /// 是否启用安全区域
  final bool safeArea;

  /// 背景颜色 (外部指定优先级最高，若为空取 Theme 值)
  final Color? backgroundColor;

  /// 文本/图标颜色 (外部指定优先级最高，若为空取 Theme 值)
  final Color? textColor;

  /// 文本配置 (默认取中文)
  final StormyRefreshTextConfig textConfig;

  const StormyRefreshConfig({
    this.triggerOffset = 44.0,
    this.processedDuration = const Duration(milliseconds: 300),
    this.iconDimension = 32.0,
    this.spacing = 0.0,
    this.textStyle,
    this.messageStyle,
    this.stateTexts,
    this.showMessage = false,
    this.safeArea = true,
    this.backgroundColor,
    this.textColor,
    StormyRefreshTextConfig? textConfig,
  }) : textConfig = textConfig ?? const StormyRefreshTextConfig();

  /// 创建默认配置
  factory StormyRefreshConfig.defaultConfig() {
    return StormyRefreshConfig(
      triggerOffset: 44.0,
      processedDuration: const Duration(milliseconds: 300),
      iconDimension: 32.0,
      spacing: 0.0,
      showMessage: false,
      safeArea: true,
      textConfig: StormyRefreshTextConfig.zhCN(),
    );
  }

  /// 复制并修改配置
  StormyRefreshConfig copyWith({
    double? triggerOffset,
    Duration? processedDuration,
    double? iconDimension,
    double? spacing,
    TextStyle? textStyle,
    TextStyle? messageStyle,
    StormyRefreshStateTexts? stateTexts,
    bool? showMessage,
    bool? safeArea,
    Color? backgroundColor,
    Color? textColor,
    StormyRefreshTextConfig? textConfig,
  }) {
    return StormyRefreshConfig(
      triggerOffset: triggerOffset ?? this.triggerOffset,
      processedDuration: processedDuration ?? this.processedDuration,
      iconDimension: iconDimension ?? this.iconDimension,
      spacing: spacing ?? this.spacing,
      textStyle: textStyle ?? this.textStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      stateTexts: stateTexts ?? this.stateTexts,
      showMessage: showMessage ?? this.showMessage,
      safeArea: safeArea ?? this.safeArea,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      textConfig: textConfig ?? this.textConfig,
    );
  }
}

/// 具体状态下的文本配置
/// 用于指定不同刷新状态下的显示文本，优先级高于 [StormyRefreshTextConfig]
class StormyRefreshStateTexts {
  /// 准备就绪
  final String? ready;

  /// 触发中
  final String? armed;

  /// 处理中
  final String? processing;

  /// 拉动中
  final String? drag;

  /// 处理完成
  final String? processed;

  /// 失败
  final String? failed;

  /// 没有更多数据
  final String? noMoreData;

  const StormyRefreshStateTexts({
    this.ready,
    this.armed,
    this.processing,
    this.drag,
    this.processed,
    this.failed,
    this.noMoreData,
  });

  /// 复制并修改配置
  StormyRefreshStateTexts copyWith({
    String? ready,
    String? armed,
    String? processing,
    String? drag,
    String? processed,
    String? failed,
    String? noMoreData,
  }) {
    return StormyRefreshStateTexts(
      ready: ready ?? this.ready,
      armed: armed ?? this.armed,
      processing: processing ?? this.processing,
      drag: drag ?? this.drag,
      processed: processed ?? this.processed,
      failed: failed ?? this.failed,
      noMoreData: noMoreData ?? this.noMoreData,
    );
  }
}
