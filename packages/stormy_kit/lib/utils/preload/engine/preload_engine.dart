import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../../tools/log_utils.dart';
import '../config/preload_config.dart';
import '../state/preload_state.dart';
import '../exception/preload_exception.dart';
import '../model/preload_task.dart';
import '../model/preload_result.dart';
import '../control/preload_semaphore.dart';
import '../tracker/preload_tracker.dart';
import 'dependency_graph.dart';

/// 取消令牌 — 支持可中断的等待
class _CancellationToken {
  _CancellationToken();

  bool _cancelled = false;
  Completer<void>? _waiter;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    if (_waiter != null && !_waiter!.isCompleted) {
      _waiter!.complete();
      _waiter = null;
    }
  }

  void reset() {
    _cancelled = false;
    _waiter = null;
  }

  Future<void> wait(Duration duration) async {
    _waiter = Completer<void>();
    final timer = Timer(duration, () {
      if (!_waiter!.isCompleted) {
        _waiter!.complete();
      }
    });
    await _waiter!.future;
    timer.cancel();
    _waiter = null;
  }
}

/// 预加载执行引擎 — 封装任务验证、依赖解析、执行、重试逻辑
class PreloadEngine {
  PreloadEngine({
    PreloadConfig? config,
    PreloadTracker? tracker,
    PreloadSemaphore? semaphore,
  }) : _config = config ?? PreloadConfig.defaultConfig,
       _tracker = tracker ?? PreloadTracker(),
       _semaphore =
           semaphore ??
           PreloadSemaphore(
             config?.maxConcurrentTasks ??
                 PreloadConfig.defaultConfig.maxConcurrentTasks,
           );

  final PreloadConfig _config;
  final PreloadTracker _tracker;
  final PreloadSemaphore _semaphore;
  final _CancellationToken _token = _CancellationToken();

  /// 执行预加载任务
  Future<PreloadExecutionResult> execute(
    List<PreloadTask> tasks, {
    ProviderContainer? container,
  }) async {
    if (tasks.isEmpty) {
      return const PreloadExecutionResult(
        result: PreloadResult.success,
        completedTasks: 0,
        failedTasks: 0,
        totalTasks: 0,
        failedTaskDetails: {},
        executionTime: Duration.zero,
      );
    }

    _token.reset();
    final startTime = DateTime.now();

    final graph = DependencyGraph(tasks);
    graph.validate();
    final executionOrder = graph.buildExecutionOrder();
    _tracker.start(tasks, startTime);

    ProviderContainer? providerContainer;
    try {
      providerContainer = container ?? ProviderContainer();
      await _executeLevels(executionOrder, providerContainer);
    } catch (e) {
      _logError('预加载执行失败', e);
      if (_config.onError != null) {
        _config.onError!(e, StackTrace.current);
      }
    } finally {
      providerContainer?.dispose();
    }

    return _buildResult(tasks, startTime);
  }

  /// 按层级执行任务
  Future<void> _executeLevels(
    List<List<PreloadTask>> levels,
    ProviderContainer container,
  ) async {
    for (var levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      if (_token.isCancelled) break;

      final levelTasks = levels[levelIndex];

      final futures = levelTasks.map((task) {
        return _semaphore.withLock(() => _executeTask(task, container));
      }).toList();

      await Future.wait(futures);

      final requiredFailed = levelTasks.any(
        (t) => t.isRequired && (_tracker.getContext(t.id)?.isFailed ?? false),
      );
      if (requiredFailed) {
        _token.cancel();
        break;
      }
    }
  }

  /// 执行单个任务（含全局检查、任务级检查、重试）
  Future<void> _executeTask(
    PreloadTask task,
    ProviderContainer container,
  ) async {
    if (_token.isCancelled) {
      _tracker.onTaskCancelled(task.id);
      return;
    }

    _tracker.onTaskStart(task.id);

    // 全局执行前检查（所有任务统一调用）
    if (_config.globalCheck != null) {
      final passed = await _runGlobalCheckLoop(task.name);
      if (!passed) return; // 检查失败已标记失败
    }

    // Provider 任务：执行 Provider（现在统一经过全局检查）
    if (task.isProviderTask) {
      await _executeProviderTask(task, container);
    }

    // 方法任务：按任务级检查策略执行
    if (task.hasCheck) {
      await _executeWithCheck(task);
    } else if (task.isMethodTask) {
      await _executeMethod(task);
    }
  }

  /// 全局检查循环（返回是否通过）
  Future<bool> _runGlobalCheckLoop(String taskName) async {
    Object? lastError;
    final maxRetries =
        _config.globalCheckMaxRetries ?? _config.defaultMaxCheckRetries;
    final retryDelay =
        _config.globalCheckRetryDelay ?? _config.defaultCheckRetryDelay;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (_token.isCancelled) {
        _log('[GLOBAL_CHECK] 已取消，任务: $taskName');
        return false;
      }

      try {
        final result = await _config.globalCheck!();
        if (result) return true;
      } catch (e) {
        lastError = e;
        _log('[GLOBAL_CHECK] 任务 $taskName 第 ${attempt + 1} 次检查失败: $e');
      }

      if (attempt < maxRetries) {
        _log(
          '[GLOBAL_CHECK] 任务 $taskName 全局检查未通过，等待 ${retryDelay.inMilliseconds}ms 后重试 (${attempt + 1}/$maxRetries)',
        );
        await Future.delayed(retryDelay);
      }
    }

    _tracker.onTaskFail(
      taskName,
      lastError ?? PreloadException('全局检查失败，已重试 $maxRetries 次'),
    );
    return false;
  }

  /// 执行 Provider 任务（含重试）
  Future<void> _executeProviderTask(
    PreloadTask task,
    ProviderContainer container,
  ) async {
    final provider = task.provider!;
    final timeout = task.timeout ?? _config.defaultTimeout;
    Object? lastError;

    for (var attempt = 0; attempt <= _config.maxRetries; attempt++) {
      if (_token.isCancelled) {
        _tracker.onTaskCancelled(task.id);
        return;
      }

      try {
        if (provider is FutureProvider ||
            provider is StreamProvider ||
            provider is AsyncNotifier) {
          await container.read(provider).future.timeout(timeout);
        } else {
          container.read(provider);
        }
        return;
      } catch (e) {
        lastError = e;
        _log('Provider任务 ${task.name} 第 ${attempt + 1} 次尝试失败: $e');

        if (attempt < _config.maxRetries) {
          final delay = _config.retryBaseDelay * (1 << attempt);
          _log('等待 ${delay.inMilliseconds}ms 后重试');
          await _token.wait(delay);
        }
      }
    }

    _tracker.onTaskFail(
      task.id,
      lastError ?? PreloadException('Provider任务执行失败'),
    );
  }

  /// 执行前检查循环（返回是否通过）
  Future<bool> _runCheckLoop(PreloadTask task) async {
    Object? lastError;

    for (var attempt = 0; attempt <= task.maxCheckRetries; attempt++) {
      if (_token.isCancelled) {
        _tracker.onTaskCancelled(task.id);
        return false;
      }

      try {
        final result = await task.checkBeforeExecute!();
        if (result) return true;
      } catch (e) {
        lastError = e;
        _log('任务 ${task.name} 第 ${attempt + 1} 次检查失败: $e');
      }

      if (attempt < task.maxCheckRetries) {
        _log(
          '任务 ${task.name} 检查未通过，等待 ${task.checkRetryDelay.inMilliseconds}ms 后重试 (${attempt + 1}/${task.maxCheckRetries})',
        );
        await Future.delayed(task.checkRetryDelay);
      }
    }

    _tracker.onTaskFail(
      task.id,
      lastError ?? PreloadException('执行前检查失败，已重试 ${task.maxCheckRetries} 次'),
    );
    return false;
  }

  /// 执行前检查 → 方法执行
  Future<void> _executeWithCheck(PreloadTask task) async {
    final passed = await _runCheckLoop(task);
    if (!passed) return; // 检查失败已标记失败

    if (task.isMethodTask) {
      await _executeMethod(task);
    }
  }

  /// 执行普通方法
  Future<void> _executeMethod(PreloadTask task) async {
    try {
      await task.method!();
      _tracker.onTaskComplete(task.id, null);
    } catch (e) {
      _logError('方法任务 ${task.name} 执行失败', e);
      _tracker.onTaskFail(task.id, e);
    }
  }

  /// 取消执行
  void cancel() {
    _token.cancel();
    _tracker.cancelAll();
    _semaphore.reset();
  }

  /// 构建执行结果
  PreloadExecutionResult _buildResult(
    List<PreloadTask> tasks,
    DateTime startTime,
  ) {
    final completedTasks = tasks
        .where((t) => _tracker.getContext(t.id)?.isSuccessful ?? false)
        .length;
    final failedTasks = tasks
        .where((t) => _tracker.getContext(t.id)?.isFailed ?? false)
        .length;

    final failedTaskDetails = <String, Object>{};
    for (final task in tasks) {
      final ctx = _tracker.getContext(task.id);
      if (ctx?.isFailed ?? false) {
        failedTaskDetails[task.name] = ctx!.error ?? 'Unknown error';
      }
    }

    final hasRequiredFailures = tasks.any(
      (t) => t.isRequired && (_tracker.getContext(t.id)?.isFailed ?? false),
    );

    final result = _token.isCancelled
        ? PreloadResult.cancelled
        : hasRequiredFailures
        ? PreloadResult.failed
        : failedTasks > 0
        ? PreloadResult.partialSuccess
        : PreloadResult.success;

    _tracker.complete(
      result == PreloadResult.success
          ? PreloadManagerState.completed
          : result == PreloadResult.failed
          ? PreloadManagerState.failed
          : PreloadManagerState.cancelled,
    );

    return PreloadExecutionResult(
      result: result,
      completedTasks: completedTasks,
      failedTasks: failedTasks,
      totalTasks: tasks.length,
      failedTaskDetails: failedTaskDetails,
      executionTime: DateTime.now().difference(startTime),
    );
  }

  void _log(String message) {
    if (_config.enableLogging) {
      StormyLog.i('[PRELOAD_ENGINE] $message');
    }
  }

  void _logError(String message, Object error) {
    if (_config.enableLogging) {
      StormyLog.e('[PRELOAD_ENGINE] $message: $error');
    }
  }
}
