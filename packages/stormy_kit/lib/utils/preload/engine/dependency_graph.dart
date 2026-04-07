import 'dart:collection';

import '../exception/preload_exception.dart';
import '../model/preload_task.dart';

/// 依赖分析器 — 封装拓扑排序和循环依赖检测
///
/// 所有任务 [PreloadTask] 统一使用字符串 ID 声明依赖，支持跨类型依赖。
class DependencyGraph {
  DependencyGraph(this.tasks) : _taskMap = {for (final t in tasks) t.id: t};

  final List<PreloadTask> tasks;
  final Map<String, PreloadTask> _taskMap;

  /// 验证任务依赖关系，检测循环依赖
  void validate() {
    final visited = <String>{};
    final recursionStack = <String>{};

    void checkCircularDependency(String taskId) {
      if (recursionStack.contains(taskId)) {
        throw CircularDependencyException(recursionStack.toList() + [taskId]);
      }

      if (visited.contains(taskId)) return;

      visited.add(taskId);
      recursionStack.add(taskId);

      final task = _taskMap[taskId];
      if (task != null) {
        for (final depId in task.dependencies) {
          if (_taskMap.containsKey(depId)) {
            checkCircularDependency(depId);
          }
        }
      }

      recursionStack.remove(taskId);
    }

    for (final task in tasks) {
      if (!visited.contains(task.id)) {
        checkCircularDependency(task.id);
      }
    }
  }

  /// 构建任务执行顺序（Kahn 拓扑排序）
  /// 返回按层级分组的任务列表，同一层级的任务可以并发执行
  List<List<PreloadTask>> buildExecutionOrder() {
    final inDegree = <String, int>{};
    final queue = Queue<String>();

    // 初始化入度
    for (final task in tasks) {
      inDegree[task.id] = task.dependencies
          .where((d) => _taskMap.containsKey(d))
          .length;
    }

    // 入度为0的任务可以立即执行
    for (final task in tasks) {
      if (inDegree[task.id] == 0) {
        queue.add(task.id);
      }
    }

    final result = <List<PreloadTask>>[];
    var remainingTasks = tasks.length;

    while (queue.isNotEmpty) {
      final levelTasks = <PreloadTask>[];

      final currentLevel = queue.length;
      for (var i = 0; i < currentLevel; i++) {
        final taskId = queue.removeFirst();
        final task = _taskMap[taskId]!;
        levelTasks.add(task);

        // 减少依赖此任务的任务的入度
        for (final otherTask in tasks) {
          if (otherTask.dependencies.contains(taskId)) {
            inDegree[otherTask.id] = (inDegree[otherTask.id] ?? 0) - 1;
            if (inDegree[otherTask.id] == 0) {
              queue.add(otherTask.id);
            }
          }
        }
      }

      if (levelTasks.isNotEmpty) {
        levelTasks.sort(
          (a, b) => b.config.priority.compareTo(a.config.priority),
        );
        result.add(levelTasks);
      }

      remainingTasks -= levelTasks.length;
    }

    if (remainingTasks > 0) {
      throw CircularDependencyException(['存在未解决的依赖关系']);
    }

    return result;
  }
}
