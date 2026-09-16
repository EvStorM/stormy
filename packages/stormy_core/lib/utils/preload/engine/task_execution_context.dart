import '../state/preload_state.dart';

/// 任务执行上下文 — 管理单个任务的执行状态
/// 替代原 PreloadTask 的可变内部状态
class TaskExecutionContext {
  TaskExecutionContext({
    required this.taskId,
    required this.taskName,
    required this.isRequired,
    Duration? timeout,
  }) : state = PreloadTaskState.pending,
       _timeout = timeout,
       _error = null,
       _startTime = null,
       _endTime = null,
       _result = null;

  /// 任务唯一标识
  final String taskId;

  /// 任务显示名称
  final String taskName;

  /// 是否为必需任务
  final bool isRequired;

  /// 超时时长
  final Duration? _timeout;

  /// 当前状态
  PreloadTaskState state;

  /// 最后一次错误
  Object? _error;

  /// 开始时间
  DateTime? _startTime;

  /// 结束时间
  DateTime? _endTime;

  /// 执行结果
  dynamic _result;

  /// 超时时长
  Duration? get timeout => _timeout;

  /// 错误
  Object? get error => _error;

  /// 开始时间
  DateTime? get startTime => _startTime;

  /// 结束时间
  DateTime? get endTime => _endTime;

  /// 执行结果
  dynamic get result => _result;

  /// 是否已完成（成功或失败）
  bool get isFinished =>
      state == PreloadTaskState.completed ||
      state == PreloadTaskState.failed ||
      state == PreloadTaskState.cancelled;

  /// 是否成功完成
  bool get isSuccessful => state == PreloadTaskState.completed;

  /// 是否失败
  bool get isFailed => state == PreloadTaskState.failed;

  /// 执行耗时
  Duration? get executionTime {
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!);
  }

  /// 标记为加载中
  void markLoading() {
    state = PreloadTaskState.loading;
    _startTime ??= DateTime.now();
  }

  /// 标记为完成
  void markCompleted(dynamic result) {
    state = PreloadTaskState.completed;
    _result = result;
    _endTime = DateTime.now();
  }

  /// 标记为失败
  void markFailed(Object error) {
    state = PreloadTaskState.failed;
    _error = error;
    _endTime = DateTime.now();
  }

  /// 标记为取消
  void markCancelled() {
    state = PreloadTaskState.cancelled;
    _endTime = DateTime.now();
  }

  @override
  String toString() {
    return 'TaskExecutionContext('
        'id: $taskId, '
        'name: $taskName, '
        'state: $state, '
        'error: $_error)';
  }
}
