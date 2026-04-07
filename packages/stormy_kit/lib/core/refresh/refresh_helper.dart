import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../config/accessor/config_accessor.dart';

import 'stormy_refresh.dart';

/// 创建默认的下拉刷新头部组件
ClassicHeader buildDefaultHeader() {
  // 从配置管理器获取刷新配置
  final refreshConfig = StormyRefresh.config;
  final theme = StormyConfigAccessor.theme;
  final textConfig = refreshConfig.textConfig;

  // 获取颜色，优先使用刷新配置中的颜色，无配置则使用主题色，最后是默认颜色
  final bodyTextColor =
      refreshConfig.textColor ?? theme?.primaryColor ?? const Color(0xFF666666);
  final contentTextColor =
      refreshConfig.textColor ?? theme?.primaryColor ?? const Color(0xFF999999);

  return ClassicHeader(
    triggerOffset: refreshConfig.triggerOffset,
    processedDuration: refreshConfig.processedDuration,
    iconDimension: refreshConfig.iconDimension,
    spacing: refreshConfig.spacing,
    textStyle:
        refreshConfig.textStyle ??
        TextStyle(fontSize: 13.sp, color: bodyTextColor),
    messageStyle:
        refreshConfig.messageStyle ??
        TextStyle(fontSize: 13.sp, color: contentTextColor),
    pullIconBuilder:
        (BuildContext context, IndicatorState state, double offset) {
          return switch (state.mode) {
            _ => const SizedBox.shrink(),
          };
        },
    readyText:
        refreshConfig.stateTexts?.ready ??
        textConfig.loading ??
        '加载中...',
    processingText:
        refreshConfig.stateTexts?.processing ??
        textConfig.loading ??
        '加载中...',
    armedText:
        refreshConfig.stateTexts?.armed ??
        textConfig.releaseToLoad ??
        '释放加载',
    dragText:
        refreshConfig.stateTexts?.drag ??
        textConfig.pullToLoad ??
        '下拉加载',
    processedText:
        refreshConfig.stateTexts?.processed ??
        textConfig.loadSuccessMessage ??
        '加载完成',
    failedText:
        refreshConfig.stateTexts?.failed ??
        textConfig.loadFailed ??
        '加载失败',
    messageText: '',
    showMessage: refreshConfig.showMessage,
    safeArea: refreshConfig.safeArea,
  );
}

/// 创建默认的上拉加载底部组件
ClassicFooter buildDefaultFooter() {
  // 从配置管理器获取刷新配置
  final refreshConfig = StormyRefresh.config;
  final theme = StormyConfigAccessor.theme;
  final textConfig = refreshConfig.textConfig;

  // 获取颜色，优先使用刷新配置中的颜色，无配置则使用主题色，最后是默认颜色
  final contentTextColor =
      refreshConfig.textColor ?? theme?.primaryColor ?? const Color(0xFF999999);

  return ClassicFooter(
    triggerOffset: refreshConfig.triggerOffset,
    processedDuration: refreshConfig.processedDuration,
    iconDimension: refreshConfig.iconDimension,
    spacing: refreshConfig.spacing,
    textStyle:
        refreshConfig.textStyle ??
        TextStyle(fontSize: 13.sp, color: contentTextColor),
    messageStyle:
        refreshConfig.messageStyle ??
        TextStyle(fontSize: 13.sp, color: contentTextColor),
    pullIconBuilder:
        (BuildContext context, IndicatorState state, double offset) {
          return switch (state.mode) {
            _ => const SizedBox.shrink(),
          };
        },
    readyText:
        refreshConfig.stateTexts?.ready ??
        textConfig.loading ??
        '加载中...',
    armedText:
        refreshConfig.stateTexts?.armed ??
        textConfig.releaseToLoad ??
        '释放加载',
    processingText:
        refreshConfig.stateTexts?.processing ??
        textConfig.loading ??
        '加载中...',
    dragText:
        refreshConfig.stateTexts?.drag ??
        textConfig.pullToLoad ??
        '下拉加载',
    processedText:
        refreshConfig.stateTexts?.processed ??
        textConfig.loadSuccessMessage ??
        '加载完成',
    failedText:
        refreshConfig.stateTexts?.failed ??
        textConfig.loadFailed ??
        '加载失败',
    messageText: textConfig.lastUpdated ?? '上次更新：%T',
    noMoreText:
        refreshConfig.stateTexts?.noMoreData ??
        textConfig.noMoreData ??
        '没有更多了',
    showMessage: refreshConfig.showMessage,
    safeArea: refreshConfig.safeArea,
  );
}

Future<void> setRefresh() async {
  EasyRefresh.defaultHeaderBuilder = () => buildDefaultHeader();
  EasyRefresh.defaultFooterBuilder = () => buildDefaultFooter();
}
