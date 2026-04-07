import '../state/preload_state.dart';

/// 预加载执行结果
class PreloadExecutionResult {
  const PreloadExecutionResult({
    required this.result,
    required this.completedTasks,
    required this.failedTasks,
    required this.totalTasks,
    required this.failedTaskDetails,
    required this.executionTime,
  });

  /// 执行结果
  final PreloadResult result;

  /// 成功完成的任务数
  final int completedTasks;

  /// 失败的任务数
  final int failedTasks;

  /// 总任务数
  final int totalTasks;

  /// 失败的任务详情
  final Map<String, Object> failedTaskDetails;

  /// 执行耗时
  final Duration executionTime;

  /// 成功率
  double get successRate => totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  /// 是否完全成功
  bool get isCompleteSuccess => result == PreloadResult.success;

  /// 是否部分成功
  bool get isPartialSuccess => result == PreloadResult.partialSuccess;

  @override
  String toString() {
    return 'PreloadExecutionResult('
        'result: $result, '
        'completed: $completedTasks/$totalTasks, '
        'successRate: ${(successRate * 100).toStringAsFixed(1)}%, '
        'time: ${executionTime.inMilliseconds}ms)';
  }
}
