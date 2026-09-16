import 'dart:async';

import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;

import '../../tools/log_utils.dart';
import '../config/preload_config.dart';
import '../state/preload_state.dart';
import '../exception/preload_exception.dart';
import '../model/preload_task.dart';
import '../model/preload_result.dart';
import '../control/preload_semaphore.dart';
import '../tracker/preload_tracker.dart';
import 'dependency_graph.dart';

class _PreloadCancelled implements Exception {}

/// Each operation owns its waiter; concurrent retries cannot overwrite one another.
class _CancellationToken {
  bool isCancelled = false;
  final Set<Completer<void>> _waiters = {};

  void cancel() {
    isCancelled = true;
    for (final waiter in _waiters.toList()) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  void reset() => isCancelled = false;

  Future<T> run<T>(Future<T> operation, Duration timeout) async {
    final waiter = Completer<void>();
    _waiters.add(waiter);
    if (isCancelled) waiter.complete();
    try {
      return await Future.any<T>([
        operation.timeout(timeout),
        waiter.future.then<T>((_) => throw _PreloadCancelled()),
      ]);
    } finally {
      _waiters.remove(waiter);
    }
  }

  Future<void> wait(Duration duration) async {
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await run(done.future, duration + const Duration(seconds: 1));
    } finally {
      timer.cancel();
    }
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
  bool _running = false;

  /// 执行预加载任务
  Future<PreloadExecutionResult> execute(
    List<PreloadTask> tasks, {
    ProviderContainer? container,
  }) async {
    if (_running) throw StateError("Preload is already running");
    if (tasks.isEmpty) {
      _tracker.start(tasks, DateTime.now());
      _tracker.complete(PreloadManagerState.completed);
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

    _tracker.start(tasks, startTime);
    _running = true;

    ProviderContainer? providerContainer;
    try {
      final graph = DependencyGraph(tasks);
      graph.validate();
      final executionOrder = graph.buildExecutionOrder();
      providerContainer = container ?? ProviderContainer();
      await _executeLevels(executionOrder, providerContainer);
    } catch (e) {
      _tracker.failAll(e);
      _logError('预加载执行失败', e);
      if (_config.onError != null) {
        _config.onError!(e, StackTrace.current);
      }
    } finally {
      if (container == null) providerContainer?.dispose();
      _running = false;
      for (final task in tasks) {
        if (!(_tracker.getContext(task.id)?.isFinished ?? true)) {
          _tracker.onTaskCancelled(task.id);
        }
      }
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

    try {
      if (_config.globalCheck != null && !await _runGlobalCheckLoop(task.id)) {
        return;
      }
      if (task.hasCheck && !await _runCheckLoop(task)) return;
      if (task.isProviderTask) {
        await _executeProviderTask(task, container);
      } else {
        await _executeMethod(task);
      }
    } on _PreloadCancelled {
      _tracker.onTaskCancelled(task.id);
    } catch (error) {
      _tracker.onTaskFail(task.id, error);
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
        final result = await _token.run(
          Future.sync(_config.globalCheck!),
          _config.defaultTimeout,
        );
        if (result) return true;
      } on _PreloadCancelled {
        rethrow;
      } catch (e) {
        lastError = e;
        _log('[GLOBAL_CHECK] 任务 $taskName 第 ${attempt + 1} 次检查失败: $e');
      }

      if (attempt < maxRetries) {
        _log(
          '[GLOBAL_CHECK] 任务 $taskName 全局检查未通过，等待 ${retryDelay.inMilliseconds}ms 后重试 (${attempt + 1}/$maxRetries)',
        );
        await _token.wait(retryDelay);
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
        final value = await _readProvider(provider, container, timeout);
        _tracker.onTaskComplete(task.id, value);
        return;
      } on _PreloadCancelled {
        rethrow;
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
        final result = await _token.run(
          Future.sync(task.checkBeforeExecute!),
          task.timeout ?? _config.defaultTimeout,
        );
        if (result) return true;
      } on _PreloadCancelled {
        rethrow;
      } catch (e) {
        lastError = e;
        _log('任务 ${task.name} 第 ${attempt + 1} 次检查失败: $e');
      }

      if (attempt < task.maxCheckRetries) {
        _log(
          '任务 ${task.name} 检查未通过，等待 ${task.checkRetryDelay.inMilliseconds}ms 后重试 (${attempt + 1}/${task.maxCheckRetries})',
        );
        await _token.wait(task.checkRetryDelay);
      }
    }

    _tracker.onTaskFail(
      task.id,
      lastError ?? PreloadException('执行前检查失败，已重试 ${task.maxCheckRetries} 次'),
    );
    return false;
  }

  Future<Object?> _readProvider(
    ProviderListenable provider,
    ProviderContainer container,
    Duration timeout,
  ) async {
    final value = container.read(provider);
    if (value is Future) return _token.run<Object?>(value, timeout);
    if (value is! AsyncValue) return value;
    final completer = Completer<Object?>();
    final subscription = container.listen<dynamic>(provider, (_, next) {
      if (completer.isCompleted || next is! AsyncValue || next.isLoading)
        return;
      if (next.hasError) {
        completer.completeError(next.error!, next.stackTrace);
      } else if (next.hasValue) {
        completer.complete(next.requireValue);
      }
    }, fireImmediately: true);
    try {
      return await _token.run(completer.future, timeout);
    } finally {
      subscription.close();
    }
  }

  /// 执行普通方法
  Future<void> _executeMethod(PreloadTask task) async {
    try {
      await _token.run(
        Future.sync(task.method!),
        task.timeout ?? _config.defaultTimeout,
      );
      _tracker.onTaskComplete(task.id, null);
    } on _PreloadCancelled {
      rethrow;
    } catch (e) {
      _logError('方法任务 ${task.name} 执行失败', e);
      _tracker.onTaskFail(task.id, e);
    }
  }

  /// 取消执行
  void cancel() {
    _token.cancel();
    _tracker.cancelAll();
    // Waiting tasks drain normally and observe cancellation before starting.
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
      (result == PreloadResult.success ||
              result == PreloadResult.partialSuccess)
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
