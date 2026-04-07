import 'dart:async';
import 'dart:math';

/// 函数工具类
///
/// 提供防抖、节流等常用函数工具，支持类型安全和取消功能
class FuncUtils {
  /// 防抖函数
  ///
  /// 延迟执行函数，如果在延迟期间再次调用，则重新计时
  ///
  /// [func] 要防抖的函数
  /// [delay] 延迟时间
  ///
  /// 返回防抖后的函数和取消函数
  ///
  /// 示例：
  /// ```dart
  /// final (debouncedFn, cancel) = FuncUtils.debounce(() {
  ///   print('执行防抖操作');
  /// }, Duration(seconds: 1));
  ///
  /// debouncedFn(); // 1秒后执行
  /// debouncedFn(); // 重新计时，1秒后执行
  /// cancel(); // 取消执行
  /// ```
  static (void Function(), void Function()) debounce(
    void Function() func,
    Duration delay,
  ) {
    Timer? timer;
    void debouncedFn() {
      timer?.cancel();
      timer = Timer(delay, func);
    }

    void cancel() {
      timer?.cancel();
      timer = null;
    }

    return (debouncedFn, cancel);
  }

  /// 防抖函数（带参数）
  ///
  /// 延迟执行函数，如果在延迟期间再次调用，则重新计时
  ///
  /// [func] 要防抖的函数
  /// [delay] 延迟时间
  ///
  /// 返回防抖后的函数和取消函数
  ///
  /// 示例：
  /// ```dart
  /// final (debouncedFn, cancel) = FuncUtils.debounceWithArgs(
  ///   (String text) => print(text),
  ///   Duration(seconds: 1),
  /// );
  ///
  /// debouncedFn('hello'); // 1秒后执行
  /// debouncedFn('world'); // 重新计时，1秒后执行
  /// ```
  static (void Function(T), void Function()) debounceWithArgs<T>(
    void Function(T) func,
    Duration delay,
  ) {
    Timer? timer;
    void debouncedFn(T arg) {
      timer?.cancel();
      timer = Timer(delay, () => func(arg));
    }

    void cancel() {
      timer?.cancel();
      timer = null;
    }

    return (debouncedFn, cancel);
  }

  /// 节流函数
  ///
  /// 限制函数执行频率，在指定时间内只执行一次
  ///
  /// [func] 要节流的函数
  /// [delay] 节流时间
  ///
  /// 返回节流后的函数和取消函数
  ///
  /// 示例：
  /// ```dart
  /// final (throttledFn, cancel) = FuncUtils.throttle(() {
  ///   print('执行节流操作');
  /// }, Duration(seconds: 1));
  ///
  /// throttledFn(); // 立即执行
  /// throttledFn(); // 被忽略
  /// throttledFn(); // 被忽略
  /// // 1秒后可以再次执行
  /// ```
  static (void Function(), void Function()) throttle(
    void Function() func,
    Duration delay,
  ) {
    bool isThrottled = false;
    Timer? timer;
    void throttledFn() {
      if (!isThrottled) {
        func();
        isThrottled = true;
        timer = Timer(delay, () {
          isThrottled = false;
          timer = null;
        });
      }
    }

    void cancel() {
      timer?.cancel();
      timer = null;
      isThrottled = false;
    }

    return (throttledFn, cancel);
  }

  /// 节流函数（带参数）
  ///
  /// 限制函数执行频率，在指定时间内只执行一次
  ///
  /// [func] 要节流的函数
  /// [delay] 节流时间
  ///
  /// 返回节流后的函数和取消函数
  static (void Function(T), void Function()) throttleWithArgs<T>(
    void Function(T) func,
    Duration delay,
  ) {
    bool isThrottled = false;
    Timer? timer;
    void throttledFn(T arg) {
      if (!isThrottled) {
        func(arg);
        isThrottled = true;
        timer = Timer(delay, () {
          isThrottled = false;
          timer = null;
        });
      }
    }

    void cancel() {
      timer?.cancel();
      timer = null;
      isThrottled = false;
    }

    return (throttledFn, cancel);
  }

  /// 在一个指定范围内随机一个整数
  ///
  /// [min] 最小值（包含）
  /// [max] 最大值（包含）
  ///
  /// 返回随机整数
  static int randomInt(int min, int max) {
    if (min > max) {
      throw ArgumentError('min ($min) 不能大于 max ($max)');
    }
    return min + Random().nextInt(max - min + 1);
  }

  /// 两个值中取最大值
  ///
  /// [a] 第一个值
  /// [b] 第二个值
  ///
  /// 返回较大的值
  static T max<T extends num>(T a, T b) {
    return a > b ? a : b;
  }

  /// 两个值中取最小值
  ///
  /// [a] 第一个值
  /// [b] 第二个值
  ///
  /// 返回较小的值
  static T min<T extends num>(T a, T b) {
    return a < b ? a : b;
  }

  /// 限制最大值
  ///
  /// 如果第一个值大于第二个值，则返回第二个值（限制最大值）
  /// 否则返回第一个值
  ///
  /// [a] 第一个值
  /// [b] 最大值限制
  ///
  /// 返回限制后的值
  ///
  /// 示例：
  /// ```dart
  /// clampMax(100, 50); // 返回 50（100被限制为50）
  /// clampMax(30, 50);  // 返回 30（30小于50，不需要限制）
  /// ```
  static double clampMax(double a, double b) {
    return a > b ? b : a;
  }

  /// 限制最小值
  ///
  /// 如果第一个值小于第二个值，则返回第二个值（限制最小值）
  /// 否则返回第一个值
  ///
  /// [a] 第一个值
  /// [b] 最小值限制
  ///
  /// 返回限制后的值
  ///
  /// 示例：
  /// ```dart
  /// clampMin(10, 50);  // 返回 50（10被限制为50）
  /// clampMin(100, 50); // 返回 100（100大于50，不需要限制）
  /// ```
  static double clampMin(double a, double b) {
    return a < b ? b : a;
  }
}
