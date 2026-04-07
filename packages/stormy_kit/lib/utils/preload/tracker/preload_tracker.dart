import 'dart:async';

import '../state/preload_state.dart';
import '../model/preload_task.dart';
import '../model/preload_progress.dart';
import '../engine/task_execution_context.dart';

/// 进度追踪器 — 监听任务状态变更，计算并推送进度更新
///
/// 支持多次 execute() 调用（每次 start() 重置状态），
/// 并对快速连续的进度更新进行去抖动，避免 UI 抖动。
class PreloadTracker {
  PreloadTracker({this.debounceThreshold = const Duration(milliseconds: 50)});

  /// 进度更新去抖动间隔
  final Duration debounceThreshold;

  final StreamController<PreloadProgress> _controller =
      StreamController<PreloadProgress>.broadcast();

  /// 进度流
  Stream<PreloadProgress> get stream => _controller.stream;

  List<TaskExecutionContext> _contexts = [];
  DateTime? _startTime;
  PreloadManagerState _state = PreloadManagerState.idle;

  /// 去抖动定时器
  Timer? _debounceTimer;

  /// 待推送的进度（用于去抖动合并）
  PreloadProgress? _pendingProgress;

  /// 当前管理器状态（暴露给 PreloadManager）
  PreloadManagerState get state => _state;

  /// 启动追踪
  void start(List<PreloadTask> tasks, [DateTime? startTime]) {
    _contexts = tasks.map((task) {
      return TaskExecutionContext(
        taskId: task.id,
        taskName: task.name,
        isRequired: task.isRequired,
        timeout: task.timeout,
      );
    }).toList();
    _startTime = startTime ?? DateTime.now();
    _state = PreloadManagerState.running;
    _emitProgress();
  }

  /// 获取任务上下文
  TaskExecutionContext? getContext(String taskId) {
    return _contexts.where((c) => c.taskId == taskId).firstOrNull;
  }

  /// 获取所有任务上下文
  List<TaskExecutionContext> get contexts => List.unmodifiable(_contexts);

  /// 任务开始执行
  void onTaskStart(String taskId) {
    final ctx = getContext(taskId);
    if (ctx != null) {
      ctx.markLoading();
      _scheduleProgressUpdate();
    }
  }

  /// 任务执行完成
  void onTaskComplete(String taskId, dynamic result) {
    final ctx = getContext(taskId);
    if (ctx != null) {
      ctx.markCompleted(result);
      _scheduleProgressUpdate();
    }
  }

  /// 任务执行失败
  void onTaskFail(String taskId, Object error) {
    final ctx = getContext(taskId);
    if (ctx != null) {
      ctx.markFailed(error);
      _scheduleProgressUpdate();
    }
  }

  /// 任务被取消
  void onTaskCancelled(String taskId) {
    final ctx = getContext(taskId);
    if (ctx != null) {
      ctx.markCancelled();
      _scheduleProgressUpdate();
    }
  }

  /// 批量取消所有任务
  void cancelAll() {
    for (final ctx in _contexts) {
      if (!ctx.isFinished) {
        ctx.markCancelled();
      }
    }
    _scheduleProgressUpdate();
  }

  /// 完成追踪
  void complete(PreloadManagerState finalState) {
    _state = finalState;
    _cancelDebounce();
    _emitProgress();
  }

  /// 重置追踪器（允许多次执行）
  void reset() {
    _cancelDebounce();
    _pendingProgress = null;
    _contexts = [];
    _startTime = null;
    _state = PreloadManagerState.idle;
  }

  /// 释放资源
  void dispose() {
    _cancelDebounce();
    _controller.close();
  }

  /// 调度进度更新（去抖动）
  void _scheduleProgressUpdate() {
    _pendingProgress = _computeProgress();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceThreshold, () {
      if (_pendingProgress != null) {
        _controller.add(_pendingProgress!);
        _pendingProgress = null;
      }
    });
  }

  /// 立即推送当前进度（取消待处理的去抖动）
  void _emitProgress() {
    _cancelDebounce();
    if (_pendingProgress != null) {
      _controller.add(_pendingProgress!);
      _pendingProgress = null;
    } else {
      _controller.add(_computeProgress());
    }
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// 计算当前进度
  PreloadProgress _computeProgress() {
    if (_startTime == null) {
      return PreloadProgress(
        state: _state,
        totalTasks: _contexts.length,
        completedTasks: 0,
        runningTasks: 0,
        failedTasks: 0,
        progress: 0.0,
      );
    }

    final completedTasks = _contexts.where((c) => c.isSuccessful).length;
    final runningTasks = _contexts
        .where((c) => c.state == PreloadTaskState.loading)
        .length;
    final failedTasks = _contexts.where((c) => c.isFailed).length;

    final failedTasksDetails = <String, Object>{};
    for (final ctx in _contexts.where((c) => c.isFailed)) {
      failedTasksDetails[ctx.taskName] = ctx.error ?? 'Unknown error';
    }

    final progress = _contexts.isNotEmpty
        ? completedTasks / _contexts.length
        : 0.0;

    Duration? estimatedTimeRemaining;
    if (progress > 0 && progress < 1.0) {
      final elapsed = DateTime.now().difference(_startTime!);
      final estimatedTotal = elapsed * (1.0 / progress);
      estimatedTimeRemaining = estimatedTotal - elapsed;
    }

    return PreloadProgress(
      state: _state,
      totalTasks: _contexts.length,
      completedTasks: completedTasks,
      runningTasks: runningTasks,
      failedTasks: failedTasks,
      progress: progress,
      failedTasksDetails: failedTasksDetails,
      startTime: _startTime,
      estimatedTimeRemaining: estimatedTimeRemaining,
    );
  }
}
