import 'package:riverpod_annotation/riverpod_annotation.dart';

/// 预加载任务 — 通用任务模型
///
/// 支持两种任务类型：
/// - [provider] 非空时为 Provider 任务（由 Riverpod 提供执行）
/// - [method] 非空时为普通方法任务（直接执行异步函数）
///
/// 依赖统一通过 [dependencies] 字符串 ID 声明，可跨类型依赖。
class PreloadTask<T> {
  const PreloadTask({
    this.provider,
    this.method,
    String? id,
    this.dependencies = const [],
    this.checkBeforeExecute,
    this.checkRetryDelay = const Duration(milliseconds: 300),
    this.maxCheckRetries = 10,
    TaskConfig? config,
  }) : _explicitId = id,
       config = config ?? const TaskConfig(),
       assert(
         provider != null || method != null,
         '任务必须提供 provider 或 method 之一',
       );

  /// Provider 实例（Provider 任务时非空）
  final ProviderListenable<T>? provider;

  /// 普通异步方法（方法任务时非空）
  final Future<void> Function()? method;

  /// 显式任务 ID
  final String? _explicitId;

  /// 依赖的其他任务 ID（字符串，支持跨类型依赖）
  /// 可引用 Provider 任务的 ID 或方法任务的 ID
  final List<String> dependencies;

  /// 执行前检查函数
  /// 返回 true 表示可以执行，返回 false 则等待后重试
  final Future<bool> Function()? checkBeforeExecute;

  /// 检查失败后的重试间隔
  final Duration checkRetryDelay;

  /// 最大检查重试次数
  final int maxCheckRetries;

  /// 任务配置
  final TaskConfig config;

  /// 任务 ID
  String get id {
    if (_explicitId != null) return _explicitId;
    final name = config.name;
    if (name != null) return name;
    if (provider != null) return provider!.runtimeType.toString();
    return 'method_task_${method.hashCode}';
  }

  /// 任务名称（用于显示）
  String get name => config.name ?? id;

  /// 是否为 Provider 任务
  bool get isProviderTask => provider != null;

  /// 是否为普通方法任务
  bool get isMethodTask => method != null;

  /// 是否为必需任务
  bool get isRequired => config.required;

  /// 超时时长
  Duration? get timeout => config.timeout;

  /// 优先级
  int get priority => config.priority;

  /// 是否有执行前检查
  bool get hasCheck => checkBeforeExecute != null;

  /// 创建副本
  PreloadTask<T> copyWith<T>({
    ProviderListenable<T>? provider,
    Future<void> Function()? method,
    String? id,
    List<String>? dependencies,
    Future<bool> Function()? checkBeforeExecute,
    Duration? checkRetryDelay,
    int? maxCheckRetries,
    TaskConfig? config,
  }) {
    return PreloadTask<T>(
      provider: provider ?? (this.provider as ProviderListenable<T>?),
      method: method ?? this.method,
      id: id ?? _explicitId,
      dependencies: dependencies ?? this.dependencies,
      checkBeforeExecute: checkBeforeExecute ?? this.checkBeforeExecute,
      checkRetryDelay: checkRetryDelay ?? this.checkRetryDelay,
      maxCheckRetries: maxCheckRetries ?? this.maxCheckRetries,
      config: config ?? this.config,
    );
  }

  @override
  String toString() {
    return 'PreloadTask(id: $id, name: $name, type: ${isProviderTask ? 'provider' : 'method'}, deps: ${dependencies.length}, hasCheck: $hasCheck)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreloadTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@override
class TaskConfig {
  const TaskConfig({
    this.priority = 1,
    this.required = true,
    this.timeout,
    this.name,
  });

  /// 任务优先级（数字越大优先级越高）
  final int priority;

  /// 任务是否必需（必需任务失败会导致整体失败）
  final bool required;

  /// 任务超时时间（null 表示使用全局配置）
  final Duration? timeout;

  /// 任务名称（用于日志和调试）
  final String? name;

  /// 创建副本并修改部分配置
  TaskConfig copyWith({
    int? priority,
    bool? required,
    Duration? timeout,
    String? name,
  }) {
    return TaskConfig(
      priority: priority ?? this.priority,
      required: required ?? this.required,
      timeout: timeout ?? this.timeout,
      name: name ?? this.name,
    );
  }
}
