import 'dart:async';
import 'dart:collection';

/// 并发控制信号量 — 实现真正的并发数限制
/// 修复原设计中 maxConcurrentTasks 定义但从未生效的问题
class PreloadSemaphore {
  PreloadSemaphore(this.maxConcurrent);

  /// 最大并发数
  final int maxConcurrent;

  /// 当前活跃的任务数
  int _active = 0;

  /// 等待队列
  final Queue<Completer<void>> _waiters = Queue();

  /// 当前等待的任务数
  int get waitingCount => _waiters.length;

  /// 当前活跃的任务数
  int get activeCount => _active;

  /// 获取信号量
  Future<void> acquire() async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
  }

  /// 释放信号量
  void release() {
    if (_waiters.isNotEmpty) {
      // 唤醒一个等待者
      final completer = _waiters.removeFirst();
      if (!completer.isCompleted) {
        completer.complete();
      }
    } else {
      _active--;
    }
  }

  /// 在信号量保护下执行任务
  Future<T> withLock<T>(Future<T> Function() task) async {
    await acquire();
    try {
      return await task();
    } finally {
      release();
    }
  }

  /// 重置信号量（清空所有等待）
  void reset() {
    for (final completer in _waiters) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Semaphore reset'));
      }
    }
    _waiters.clear();
    _active = 0;
  }
}
