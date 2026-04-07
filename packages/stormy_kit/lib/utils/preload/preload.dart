/// 预加载管理器模块
///
/// 提供统一的Riverpod Provider预加载管理功能，支持：
/// - 自动依赖管理
/// - 并发执行控制
/// - 进度追踪
/// - 错误处理和重试
/// - 类型安全
///
/// 架构说明：
/// - `PreloadManager` — Facade模式，对外API入口
/// - `PreloadEngine` — 核心执行引擎，封装任务执行逻辑
/// - `DependencyGraph` — 依赖分析器，处理拓扑排序和循环检测
/// - `PreloadTracker` — 进度追踪器，计算和推送进度更新
/// - `PreloadSemaphore` — 并发信号量，控制最大并发数
///
/// 使用示例：
/// ```dart
/// await PreloadManager.instance
///   .register(myProvider, priority: 1)
///   .register(
///     dependentProvider,
///     deps: [myProvider],
///     priority: 2,
///   )
///   .execute();
/// ```
library;

export 'preload_manager.dart';
export 'config/preload_config.dart';
export 'model/preload_task.dart';
export 'model/preload_result.dart';
export 'model/preload_progress.dart';
export 'engine/preload_engine.dart';
export 'engine/dependency_graph.dart';
export 'engine/task_execution_context.dart';
export 'tracker/preload_tracker.dart';
export 'control/preload_semaphore.dart';
export 'state/preload_state.dart';
export 'exception/preload_exception.dart';
