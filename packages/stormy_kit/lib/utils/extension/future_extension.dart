import 'dart:async';

/// 重试延迟策略
enum RetryDelayStrategy {
  /// 固定延迟，每次等待相同时间
  fixed,

  /// 线性递增，每次数组索引越大延迟越长
  linear,

  /// 指数退避，每次延迟翻倍（越来越慢）
  exponential,

  /// 指数衰减，delayFactor &lt; 1 时越来越快
  decay,
}

/// 预定义延迟数组，用于 [RetryDelayStrategy.linear]
const defaultLinearDelays = [
  Duration(milliseconds: 200),
  Duration(milliseconds: 500),
  Duration(milliseconds: 1000),
  Duration(milliseconds: 2000),
  Duration(milliseconds: 5000),
];

double _pow(double base, int exponent) {
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

Duration _computeDelay({
  required int attempt,
  required Duration baseDelay,
  required RetryDelayStrategy strategy,
  required double delayFactor,
  required List<Duration> linearDelays,
}) {
  switch (strategy) {
    case RetryDelayStrategy.fixed:
      return baseDelay;
    case RetryDelayStrategy.linear:
      final index = (attempt - 1).clamp(0, linearDelays.length - 1);
      return linearDelays[index];
    case RetryDelayStrategy.exponential:
      return baseDelay * (1 << (attempt - 1));
    case RetryDelayStrategy.decay:
      final multiplier = _pow(delayFactor, attempt - 1);
      return baseDelay * multiplier;
  }
}

/// 执行工厂函数 [fn]，重复创建新实例直到 [condition] 满足
/// [fn] 返回 Future 的工厂函数，每次重试都会重新调用
/// [condition] 满足条件，返回 true 时结束重试
/// [maxRetry] 最大重试次数
/// [retryDelay] 重试延迟（用于 [RetryDelayStrategy.fixed] 和 [RetryDelayStrategy.exponential] 的初始值）
/// [timeout] 超时时间
/// [delayStrategy] 延迟策略，默认为 [RetryDelayStrategy.fixed]
/// [delayFactor] 指数衰减的倍率因子（仅 [RetryDelayStrategy.decay] 生效），默认 0.5（每次减半）
/// [linearDelays] 线性递增策略使用的延迟数组（仅 [RetryDelayStrategy.linear] 生效）
/// 返回满足 [condition] 的结果
Future<T> recursiveCall<T>({
  required Future<T> Function() fn,
  required bool Function(T) condition,
  int maxRetry = 3,
  Duration retryDelay = const Duration(seconds: 1),
  Duration timeout = const Duration(seconds: 10),
  RetryDelayStrategy delayStrategy = RetryDelayStrategy.fixed,
  double delayFactor = 0.5,
  List<Duration> linearDelays = defaultLinearDelays,
}) async {
  final start = DateTime.now();
  int attempt = 0;
  while (DateTime.now().difference(start) < timeout && attempt < maxRetry) {
    final result = await fn();
    if (condition(result)) {
      return result;
    }
    attempt++;
    if (attempt < maxRetry) {
      await Future.delayed(
        _computeDelay(
          attempt: attempt,
          baseDelay: retryDelay,
          strategy: delayStrategy,
          delayFactor: delayFactor,
          linearDelays: linearDelays,
        ),
      );
    }
  }
  throw Exception('Recursive call timed out or max retries exceeded');
}

extension PollUntilExt<T> on Future? {
  /// 轮询检查 `this` Future，条件满足后执行 [this]
  /// [maxRetry] 最大重试次数
  /// [retryDelay] 重试延迟（用于 [RetryDelayStrategy.fixed] 和 [RetryDelayStrategy.exponential] 的初始值）
  /// [timeout] 超时时间
  /// [delayStrategy] 延迟策略
  /// [delayFactor] 指数衰减的倍率因子
  /// [linearDelays] 线性递增策略使用的延迟数组
  /// 返回 [fn] 的执行结果
  Future<R> pollUntil<R>({
    required FutureOr<bool> Function() check,
    int maxRetry = 3,
    Duration retryDelay = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 10),
    RetryDelayStrategy delayStrategy = RetryDelayStrategy.fixed,
    double delayFactor = 0.5,
    List<Duration> linearDelays = defaultLinearDelays,
  }) async {
    final start = DateTime.now();
    int attempt = 0;
    while (DateTime.now().difference(start) < timeout && attempt < maxRetry) {
      if (await check()) {
        return await this;
      }
      attempt++;
      if (attempt < maxRetry) {
        await Future.delayed(
          _computeDelay(
            attempt: attempt,
            baseDelay: retryDelay,
            strategy: delayStrategy,
            delayFactor: delayFactor,
            linearDelays: linearDelays,
          ),
        );
      }
    }
    throw Exception('Poll timed out or max retries exceeded');
  }
}
