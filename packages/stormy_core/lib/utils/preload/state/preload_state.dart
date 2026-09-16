/// 预加载状态枚举
enum PreloadTaskState {
  /// 等待执行
  pending,

  /// 正在加载
  loading,

  /// 已完成
  completed,

  /// 执行失败
  failed,

  /// 已取消
  cancelled,
}

/// 预加载管理器整体状态
enum PreloadManagerState {
  /// 空闲状态
  idle,

  /// 正在执行
  running,

  /// 执行完成
  completed,

  /// 执行失败
  failed,

  /// 已取消
  cancelled,
}

/// 预加载结果
enum PreloadResult {
  /// 成功
  success,

  /// 部分成功（某些非必需任务失败）
  partialSuccess,

  /// 失败
  failed,

  /// 取消
  cancelled,
}
