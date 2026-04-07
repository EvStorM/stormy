import 'package:flutter/material.dart';

/// ==================== App 生命周期事件 ====================

/// App 生命周期状态
enum AppLifecycleStatus {
  /// 应用打开（首次或从后台恢复可见）
  resumed,

  /// 应用处于非激活状态（iOS 切换任务、Android 对话框）
  inactive,

  /// 应用进入后台
  paused,

  /// 应用被终止
  detached,
}

/// App 生命周期状态监听器
///
/// 使用 WidgetsBindingObserver 监听应用的可见性变化，
/// 包括应用打开、进入后台、从后台恢复等状态。
class AppLifecycleStateListener with WidgetsBindingObserver {
  AppLifecycleStateListener({
    this.onStatusChanged,
    this.onResumed,
    this.onPaused,
    this.onInactive,
    this.onDetached,
  });

  final void Function(AppLifecycleStatus status)? onStatusChanged;
  final void Function()? onResumed;
  final void Function()? onPaused;
  final void Function()? onInactive;
  final void Function()? onDetached;

  bool _isAttached = false;

  /// 将监听器附加到 WidgetsBinding
  void attach() {
    if (!_isAttached) {
      WidgetsBinding.instance.addObserver(this);
      _isAttached = true;
    }
  }

  /// 检查是否已附加
  bool get isAttached => _isAttached;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onStatusChanged?.call(AppLifecycleStatus.resumed);
        onResumed?.call();
      case AppLifecycleState.inactive:
        onStatusChanged?.call(AppLifecycleStatus.inactive);
        onInactive?.call();
      case AppLifecycleState.paused:
        onStatusChanged?.call(AppLifecycleStatus.paused);
        onPaused?.call();
      case AppLifecycleState.detached:
        onStatusChanged?.call(AppLifecycleStatus.detached);
        onDetached?.call();
      case AppLifecycleState.hidden:
        onStatusChanged?.call(AppLifecycleStatus.paused);
        onPaused?.call();
    }
  }

  /// 从 WidgetsBinding 分离监听器
  void dispose() {
    if (_isAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _isAttached = false;
    }
  }
}

/// App 生命周期管理器 - 单例模式
///
/// 提供全局的 App 生命周期状态管理。
class AppLifecycleManager {
  AppLifecycleManager._();

  static final AppLifecycleManager instance = AppLifecycleManager._();

  AppLifecycleStatus _currentStatus = AppLifecycleStatus.resumed;
  AppLifecycleStatus get currentStatus => _currentStatus;

  final List<void Function(AppLifecycleStatus status)> _listeners = [];

  /// 添加生命周期状态监听
  void addListener(void Function(AppLifecycleStatus status) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// 移除生命周期状态监听
  void removeListener(void Function(AppLifecycleStatus status) listener) {
    _listeners.remove(listener);
  }

  void _notifyStatus(AppLifecycleStatus status) {
    _currentStatus = status;
    for (final listener in _listeners) {
      listener(status);
    }
  }

  /// 内部方法，由 AppLifecycleStateListener 调用
  void notifyStatus(AppLifecycleStatus status) {
    _notifyStatus(status);
  }

  /// 检查应用是否在后台
  bool get isInBackground =>
      _currentStatus == AppLifecycleStatus.paused ||
      _currentStatus == AppLifecycleStatus.detached;

  /// 检查应用是否可见
  bool get isVisible => _currentStatus == AppLifecycleStatus.resumed;
}
