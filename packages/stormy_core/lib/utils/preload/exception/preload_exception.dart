/// 预加载相关异常
class PreloadException implements Exception {
  PreloadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PreloadException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// 循环依赖异常
class CircularDependencyException extends PreloadException {
  CircularDependencyException(List<String> cycle)
    : super('检测到循环依赖: ${cycle.join(' -> ')}');
}

/// 任务超时异常
class PreloadTimeoutException extends PreloadException {
  PreloadTimeoutException(String taskName, Duration timeout)
    : super('任务 "$taskName" 执行超时 (${timeout.inSeconds}s)');
}

/// 任务失败异常
class PreloadTaskFailedException extends PreloadException {
  PreloadTaskFailedException(String taskName, Object error)
    : super('任务 "$taskName" 执行失败', cause: error);
}

/// 配置异常
class PreloadConfigException extends PreloadException {
  PreloadConfigException(String message) : super('配置错误: $message');
}
