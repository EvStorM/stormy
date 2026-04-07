import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../stormy_kit.dart';
import 'config/preload_config.dart';
import 'model/preload_task.dart';
import 'model/preload_result.dart';
import 'model/preload_progress.dart';
import 'engine/preload_engine.dart';
import 'state/preload_state.dart';
import 'tracker/preload_tracker.dart';
import 'exception/preload_exception.dart';

/// 预加载管理器 — Facade 模式，负责任务注册、状态流转、对外 API
class PreloadManager {
  PreloadManager._();

  /// 单例实例
  static final PreloadManager _instance = PreloadManager._();
  static PreloadManager get instance => _instance;

  /// 全局配置
  PreloadConfig _config = PreloadConfig.defaultConfig;

  /// 注册的任务列表
  final List<PreloadTask> _registeredTasks = [];

  /// 执行引擎（延迟创建，确保使用最新配置）
  PreloadEngine? _engine;

  /// 内部共享的 tracker 实例（Engine 持有同一个引用）
  final _tracker = PreloadTracker();

  /// 获取执行引擎
  PreloadEngine _getEngine() {
    return _engine ??= PreloadEngine(config: _config, tracker: _tracker);
  }

  /// 配置管理
  void configure(PreloadConfig config) {
    _config = config;
    _engine = PreloadEngine(config: _config, tracker: _tracker);
    _log(
      '[CONFIG] 预加载管理器配置已更新: '
      'maxConcurrentTasks=${config.maxConcurrentTasks}, '
      'defaultTimeout=${config.defaultTimeout}, '
      'enableLogging=${config.enableLogging}',
    );
  }

  /// 注册预加载任务 — 智能识别 Provider 或普通方法
  ///
  /// 自动判断类型：
  /// - [target] 为 [ProviderListenable] → Provider 任务
  /// - [target] 为 [Function]（异步方法）→ 普通方法任务
  ///
  /// Provider 任务示例：
  /// ```dart
  /// PreloadManager.instance.register(myProvider, name: 'user-data');
  /// ```
  ///
  /// 普通方法任务示例（需显式传入异步函数）：
  /// ```dart
  /// PreloadManager.instance.register(() async {
  ///   await db.initialize();
  /// }, name: 'db-init');
  /// ```
  PreloadManager register<T>(
    T target, {
    String? name,
    List<String> dependencies = const [],
    Future<bool> Function()? checkBeforeExecute,
    Duration? checkRetryDelay,
    int maxCheckRetries = 10,
    int priority = 1,
    bool required = true,
    Duration? timeout,
  }) {
    PreloadTask task;

    if (target is ProviderListenable) {
      // Provider 任务
      task = PreloadTask(
        provider: target as ProviderListenable<T>,
        id: name ?? target.runtimeType.toString(),
        dependencies: dependencies,
        checkBeforeExecute: checkBeforeExecute,
        checkRetryDelay: checkRetryDelay ?? _config.defaultCheckRetryDelay,
        maxCheckRetries: maxCheckRetries,
        config: TaskConfig(
          priority: priority,
          required: required,
          timeout: timeout,
          name: name,
        ),
      );
    } else if (target is Future<void> Function()) {
      // 普通方法任务
      task = PreloadTask(
        method: target as Future<void> Function(),
        id: name ?? 'method_${target.hashCode}',
        dependencies: dependencies,
        checkBeforeExecute: checkBeforeExecute,
        checkRetryDelay: checkRetryDelay ?? _config.defaultCheckRetryDelay,
        maxCheckRetries: maxCheckRetries,
        config: TaskConfig(
          priority: priority,
          required: required,
          timeout: timeout,
          name: name,
        ),
      );
    } else {
      throw PreloadException(
        'register() 仅支持 ProviderListenable 或 Future<void> Function()，'
        '传入类型为: ${target.runtimeType}',
      );
    }

    _registeredTasks.add(task);
    _log(
      '[REGISTER] 注册任务: id=${task.id}, type=${task.isProviderTask ? 'provider' : 'method'}, '
      'priority=$priority, required=$required, hasCheck=${task.hasCheck}',
    );
    return this;
  }

  /// 批量注册任务
  PreloadManager registerBatch(List<PreloadTask> tasks) {
    _registeredTasks.addAll(tasks);
    _log(
      '[REGISTER_BATCH] 批量注册 ${tasks.length} 个任务: '
      '${tasks.map((t) => t.id).join(', ')}',
    );
    return this;
  }

  /// 清空所有注册的任务
  void clear() {
    _log('[CLEAR] 清空所有注册的任务，当前任务数: ${_registeredTasks.length}');
    _registeredTasks.clear();
    if (_tracker.state == PreloadManagerState.running) {
      cancel();
    }
    _tracker.reset();
    _log('[CLEAR] 清空完成');
  }

  /// 执行预加载
  Future<PreloadExecutionResult> execute({ProviderContainer? container}) async {
    _log('[EXECUTE] ========== 预加载开始执行 ==========');
    _log('[EXECUTE] 当前注册任务数: ${_registeredTasks.length}');

    if (_registeredTasks.isEmpty) {
      _log('[EXECUTE] 没有注册任务，直接返回成功');
      return const PreloadExecutionResult(
        result: PreloadResult.success,
        completedTasks: 0,
        failedTasks: 0,
        totalTasks: 0,
        failedTaskDetails: {},
        executionTime: Duration.zero,
      );
    }

    if (_tracker.state == PreloadManagerState.running) {
      _log('[EXECUTE] 预加载已在进行中，抛出异常');
      throw PreloadException('预加载已在进行中');
    }

    _log('[EXECUTE] 状态设置为: running');

    try {
      final result = await _getEngine().execute(
        _registeredTasks,
        container: container,
      );

      _log('[EXECUTE] ========== 预加载执行完成 ==========');
      _log(
        '[EXECUTE] 结果: ${result.result}, '
        '成功: ${result.completedTasks}, '
        '失败: ${result.failedTasks}, '
        '耗时: ${result.executionTime.inMilliseconds}ms',
      );

      return result;
    } catch (e) {
      _logError('[EXECUTE] 预加载执行失败', e);

      if (_config.onError != null) {
        _config.onError!(e, StackTrace.current);
      }

      return PreloadExecutionResult(
        result: PreloadResult.failed,
        completedTasks: 0,
        failedTasks: _registeredTasks.length,
        totalTasks: _registeredTasks.length,
        failedTaskDetails: {e.toString(): e},
        executionTime: Duration.zero,
      );
    }
  }

  /// 取消当前执行
  void cancel() {
    _log('[CANCEL] ========== 收到取消请求 ==========');
    if (_tracker.state != PreloadManagerState.running) {
      _log('[CANCEL] 当前状态不是 running，无法取消，状态: ${_tracker.state}');
      return;
    }

    _getEngine().cancel();
    _log('[CANCEL] 状态设置为: cancelled');
  }

  /// 获取当前进度流
  Stream<PreloadProgress> get progress => _tracker.stream;

  /// 获取当前状态
  PreloadManagerState get state => _tracker.state;

  void _log(String message) {
    if (_config.enableLogging) {
      StormyLog.i('[PRELOAD_MGR] $message');
    }
  }

  void _logError(String message, Object error) {
    if (_config.enableLogging) {
      StormyLog.e('[PRELOAD_MGR] $message: $error');
    }
  }
}
