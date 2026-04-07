/// 预加载全局配置
class PreloadConfig {
  const PreloadConfig({
    this.maxConcurrentTasks = 3,
    this.defaultTimeout = const Duration(seconds: 30),
    this.maxRetries = 2,
    this.retryBaseDelay = const Duration(milliseconds: 500),
    this.enableLogging = true,
    this.onError,
    this.defaultCheckRetryDelay = const Duration(milliseconds: 300),
    this.defaultMaxCheckRetries = 10,
    this.globalCheck,
    this.globalCheckRetryDelay,
    this.globalCheckMaxRetries,
  });

  /// 最大并发任务数
  final int maxConcurrentTasks;

  /// 默认任务超时时间
  final Duration defaultTimeout;

  /// 任务失败重试次数
  final int maxRetries;

  /// 重试间隔基数（指数退避）
  final Duration retryBaseDelay;

  /// 是否启用详细日志
  final bool enableLogging;

  /// 全局错误处理回调
  final void Function(Object error, StackTrace? stackTrace)? onError;

  /// 默认执行前检查重试间隔
  final Duration defaultCheckRetryDelay;

  /// 默认执行前检查最大重试次数
  final int defaultMaxCheckRetries;

  /// 全局执行前检查 — 每个任务执行前都会调用
  /// 返回 true 表示可以执行，返回 false 则等待后重试
  /// 适用于检查应用状态（前台/后台）、网络连接、设备资源等全局前置条件
  final Future<bool> Function()? globalCheck;

  /// 全局检查失败后的重试间隔（null 使用 defaultCheckRetryDelay）
  final Duration? globalCheckRetryDelay;

  /// 全局检查最大重试次数（null 使用 defaultMaxCheckRetries）
  final int? globalCheckMaxRetries;

  /// 默认配置
  static const PreloadConfig defaultConfig = PreloadConfig();

  /// 创建副本并修改部分配置
  PreloadConfig copyWith({
    int? maxConcurrentTasks,
    Duration? defaultTimeout,
    int? maxRetries,
    Duration? retryBaseDelay,
    bool? enableLogging,
    void Function(Object error, StackTrace? stackTrace)? onError,
    Duration? defaultCheckRetryDelay,
    int? defaultMaxCheckRetries,
    Future<bool> Function()? globalCheck,
    Duration? globalCheckRetryDelay,
    int? globalCheckMaxRetries,
  }) {
    return PreloadConfig(
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
      defaultTimeout: defaultTimeout ?? this.defaultTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      retryBaseDelay: retryBaseDelay ?? this.retryBaseDelay,
      enableLogging: enableLogging ?? this.enableLogging,
      onError: onError ?? this.onError,
      defaultCheckRetryDelay:
          defaultCheckRetryDelay ?? this.defaultCheckRetryDelay,
      defaultMaxCheckRetries:
          defaultMaxCheckRetries ?? this.defaultMaxCheckRetries,
      globalCheck: globalCheck ?? this.globalCheck,
      globalCheckRetryDelay:
          globalCheckRetryDelay ?? this.globalCheckRetryDelay,
      globalCheckMaxRetries:
          globalCheckMaxRetries ?? this.globalCheckMaxRetries,
    );
  }
}
