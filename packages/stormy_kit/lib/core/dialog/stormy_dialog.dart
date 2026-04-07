import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../config/models/dialog_config.dart';
import '../../core/storage/stormy_storage.dart';
import '../../widgets/dialog/stormy_alert_dialog.dart';
import '../../widgets/dialog/stormy_confirm_dialog.dart';
import '../../widgets/special/h5/h5.dart';
import '../../widgets/special/privacy/privacy_policy.dart';

/// StormyDialog - 统一弹窗入口
/// 负责全局的配置化弹窗调度（支持 bottom、center、top）
class StormyDialog {
  static StormyDialog? _instance;
  static StormyDialog get instance => _instance ??= StormyDialog._();

  StormyDialog._();

  /// 全局 Navigator Key，用于无 BuildContext 调用 (主要用于 modal_bottom_sheet 兜底)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  StormyDialogConfig _config = StormyDialogConfig.defaultConfig();

  /// 是否已初始化
  bool get isInitialized => _config != StormyDialogConfig.defaultConfig();

  /// 获取当前全局配置
  StormyDialogConfig get config => _config;

  /// 初始化弹窗模块
  void initialize(StormyDialogConfig config) {
    _config = config;
  }

  /// 更新全局配置
  void updateConfig(StormyDialogConfig config) {
    _config = config;
  }

  /// 内部核心路由分发器
  /// 将组件[widget] 放置在指定 [position] 并利用合适的包弹出
  Future<T?> _showPositionedDialog<T>({
    required Widget widget,
    required StormyDialogPosition position,
    required StormyDialogUIConfig uiConfig,
    String tag = 'stormy_dialog',
  }) async {
    switch (position) {
      case StormyDialogPosition.bottom:
        // 如果外部没有包 Navigator 或没有 Context 会为空，强制依赖 Context 时需从 navigatorKey 取
        final context = navigatorKey.currentContext;
        if (context == null) return null;

        return await showMaterialModalBottomSheet<T>(
          context: context,
          backgroundColor: Colors.transparent,
          isDismissible: uiConfig.barrierDismissible ?? true,
          barrierColor: uiConfig.barrierColor,
          builder: (context) => widget,
        );

      case StormyDialogPosition.center:
        return await SmartDialog.show<T>(
          tag: tag,
          alignment: Alignment.center,
          clickMaskDismiss: uiConfig.barrierDismissible ?? false,
          maskColor: uiConfig.barrierColor ?? Colors.black.withAlpha(128),
          builder: (context) => widget,
        );

      case StormyDialogPosition.top:
        return await SmartDialog.show<T>(
          tag: tag,
          alignment: Alignment.topCenter,
          clickMaskDismiss: uiConfig.barrierDismissible ?? false,
          maskColor: uiConfig.barrierColor ?? Colors.black.withAlpha(128),
          builder: (context) => widget,
        );
    }
  }

  /// 显示提示单按钮对话框 (Alert)
  Future<bool?> showAlert({
    String? title,
    required String message,
    Widget? child,
    StormyDialogPosition? position,
    StormyDialogUIConfig? overrideConfig,
    String dialogTag = 'stormy_alert',
  }) async {
    // 处理配置的合并：全局默认 -> 个性化覆盖
    final resolvedConfig = _config.alertConfig.merge(overrideConfig);
    final resolvedPosition = position ?? _config.defaultPosition;

    final widget = StormyAlertDialog(
      config: resolvedConfig,
      position: resolvedPosition,
      content: message,
      title: title,
      child: child,
    );

    return _showPositionedDialog<bool>(
      widget: widget,
      position: resolvedPosition,
      uiConfig: resolvedConfig,
      tag: dialogTag,
    );
  }

  /// 显示双按钮确认对话框 (Confirm)
  Future<bool?> showConfirm({
    required String title,
    String? message,
    Widget? child,
    StormyDialogPosition? position,
    StormyDialogUIConfig? overrideConfig,
    String dialogTag = 'stormy_confirm',
  }) async {
    final resolvedConfig = _config.confirmConfig.merge(overrideConfig);
    final resolvedPosition = position ?? _config.defaultPosition;

    final widget = StormyConfirmDialog(
      config: resolvedConfig,
      position: resolvedPosition,
      title: title,
      content: message,
      child: child,
    );

    return _showPositionedDialog<bool>(
      widget: widget,
      position: resolvedPosition,
      uiConfig: resolvedConfig,
      tag: dialogTag,
    );
  }

  /// 显示自定义组件弹窗 (Custom)
  Future<T?> showCustom<T>({
    required Widget child,
    StormyDialogPosition? position,
    StormyDialogUIConfig? overrideConfig,
    String dialogTag = 'stormy_custom',
  }) async {
    // 自定义时仅依赖最基础的安全配置合并
    final resolvedConfig = StormyDialogUIConfig.defaultConfig().merge(
      overrideConfig,
    );
    final resolvedPosition = position ?? _config.defaultPosition;

    return _showPositionedDialog<T>(
      widget: child,
      position: resolvedPosition,
      uiConfig: resolvedConfig,
      tag: dialogTag,
    );
  }

  /// 纯手动控制关闭弹窗
  void dismiss<T>({String? tag, T? result, bool force = true}) {
    SmartDialog.dismiss(tag: tag, result: result, force: force);
    // bottom modal 无法通过外部 api 直接杀，需要通过拿 navigator pop
  }

  static const String _privacyStorageKey = 'stormy_privacy_agreed';

  /// 默认 H5 页面打开方式 (主要用于隐私协议弹窗)
  void openH5(BuildContext context, String url, String title) {
    showCupertinoModalBottomSheet(
      context: context,
      useRootNavigator: true,
      enableDrag: false,
      builder: (context) =>
          H5(extra: {'title': title, 'url': url, 'nav': true}),
    );
  }

  /// 检查是否已同意隐私协议，未同意则弹出对话框并监听结果
  /// 当返回 true 代表已经同意
  Future<bool> showPrivacyDialog(
    BuildContext context, {
    VoidCallback? onDone,
    StormyPrivacyConfig? overrideConfig,
  }) async {
    final config =
        overrideConfig ??
        StormyPrivacyConfig.instance ??
        const StormyPrivacyConfig();

    // 判断是否同意
    bool agreed = false;
    if (config.getLocalPrivacyAgreed != null) {
      agreed = await config.getLocalPrivacyAgreed!();
    } else {
      agreed = StormyStorage.instance.getBool(_privacyStorageKey) ?? false;
    }

    if (agreed) {
      onDone?.call();
      return true;
    }

    // 显示隐私弹窗
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacyPolicyDialog(
        config: config,
        onAgree: () => Navigator.pop(context, true),
        onDisagree: () => Navigator.pop(context, false),
      ),
    );

    if (result == true) {
      // 保存状态
      if (config.saveLocalPrivacyAgreed != null) {
        await config.saveLocalPrivacyAgreed!(true);
      } else {
        await StormyStorage.instance.setBool(_privacyStorageKey, true);
      }
      onDone?.call();
      return true;
    } else {
      // 拒绝了，弹出确认退出
      if (config.showExitConfirmDialog != null) {
        final shouldExit = await config.showExitConfirmDialog!(context);
        if (!shouldExit) {
          // 不退出，重新显示隐私弹窗
          return showPrivacyDialog(
            context,
            onDone: onDone,
            overrideConfig: overrideConfig,
          );
        }
      } else {
        // 默认实现为再弹一个警告确认框
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(config.uiConfig.exitConfirm.title),
            content: Text(config.uiConfig.exitConfirm.content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  config.uiConfig.exitConfirm.cancelText,
                  style: config.uiConfig.exitConfirm.cancelTextColor != null
                      ? TextStyle(
                          color: config.uiConfig.exitConfirm.cancelTextColor,
                        )
                      : null,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  config.uiConfig.exitConfirm.confirmText,
                  style: TextStyle(
                    color:
                        config.uiConfig.exitConfirm.confirmTextColor ??
                        Colors.red,
                  ),
                ),
              ),
            ],
          ),
        );
        if (confirm != true) {
          // 反悔，重新显示
          return showPrivacyDialog(
            context,
            onDone: onDone,
            overrideConfig: overrideConfig,
          );
        } else {
          exit(0);
        }
      }
    }
    return false;
  }

  /// 重置实例（用于测试）
  static void reset() {
    _instance = null;
  }
}
