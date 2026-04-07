import '../state/preload_state.dart';

/// 预加载进度信息
class PreloadProgress {
  const PreloadProgress({
    required this.state,
    required this.totalTasks,
    required this.completedTasks,
    required this.runningTasks,
    required this.failedTasks,
    required this.progress,
    this.startTime,
    this.estimatedTimeRemaining,
    this.failedTasksDetails = const {},
  });

  /// 当前状态
  final PreloadManagerState state;

  /// 总任务数
  final int totalTasks;

  /// 已完成任务数
  final int completedTasks;

  /// 正在进行的任务数
  final int runningTasks;

  /// 失败的任务数
  final int failedTasks;

  /// 完成百分比 (0.0 - 1.0)
  final double progress;

  /// 失败的任务详情
  final Map<String, Object> failedTasksDetails;

  /// 开始时间
  final DateTime? startTime;

  /// 预计剩余时间（基于当前进度计算）
  final Duration? estimatedTimeRemaining;

  /// 完成百分比（格式化的字符串）
  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  /// 是否正在进行
  bool get isRunning => state == PreloadManagerState.running;

  /// 是否已完成
  bool get isCompleted => state == PreloadManagerState.completed;

  /// 是否失败
  bool get isFailed => state == PreloadManagerState.failed;

  /// 创建初始进度
  static PreloadProgress initial(int totalTasks) {
    return PreloadProgress(
      state: PreloadManagerState.idle,
      totalTasks: totalTasks,
      completedTasks: 0,
      runningTasks: 0,
      failedTasks: 0,
      progress: 0.0,
    );
  }

  /// 创建副本并修改部分属性
  PreloadProgress copyWith({
    PreloadManagerState? state,
    int? totalTasks,
    int? completedTasks,
    int? runningTasks,
    int? failedTasks,
    double? progress,
    Map<String, Object>? failedTasksDetails,
    DateTime? startTime,
    Duration? estimatedTimeRemaining,
  }) {
    return PreloadProgress(
      state: state ?? this.state,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      runningTasks: runningTasks ?? this.runningTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      progress: progress ?? this.progress,
      failedTasksDetails: failedTasksDetails ?? this.failedTasksDetails,
      startTime: startTime ?? this.startTime,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
    );
  }

  @override
  String toString() {
    return 'PreloadProgress('
        'state: $state, '
        'progress: $progressPercentage, '
        'completed: $completedTasks/$totalTasks, '
        'running: $runningTasks, '
        'failed: $failedTasks)';
  }
}
