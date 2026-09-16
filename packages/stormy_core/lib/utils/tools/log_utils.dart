import 'package:talker/talker.dart';

/// 日志过滤器接口
///
/// 通过实现此接口自定义日志过滤规则，可组合多个过滤器形成过滤链。
/// 任意一个过滤器返回 false，该日志即被过滤掉。
///
/// 示例：自定义过滤器只记录包含 "API" 前缀的错误级别日志
/// ```dart
/// class ApiErrorFilter implements LogFilter {
///   @override
///   bool shouldLog(String key, LogLevel level, String message, String? prefix) {
///     return level == LogLevel.error &&
///            (prefix == null || prefix.contains('API'));
///   }
/// }
/// ```
abstract class LogFilter {
  /// 判断指定日志是否应该被记录
  ///
  /// [key]   日志键名，对应 [TalkerKey] 中的常量，如 `TalkerKey.error`
  /// [level] 日志级别，对应 [LogLevel] 枚举
  /// [message] 日志消息内容
  /// [prefix] 日志前缀
  ///
  /// 返回 true 表示记录该日志，false 表示过滤掉该日志
  bool shouldLog(String key, LogLevel level, String message, String? prefix);
}

/// 日志等级过滤器
///
/// 通过设置允许的日志等级集合来过滤日志，不在集合中的等级将被过滤。
///
/// 示例：只记录 error 和 warning 级别的日志
/// ```dart
/// final filter = LevelLogFilter(
///   allowedLevels: {LogLevel.error, LogLevel.warning},
/// );
/// ```
class LevelLogFilter implements LogFilter {
  /// 允许记录的日志等级集合
  final Set<LogLevel> allowedLevels;

  /// 创建日志等级过滤器
  ///
  /// [allowedLevels] 允许的日志等级集合，默认为所有等级
  LevelLogFilter({Set<LogLevel>? allowedLevels})
    : allowedLevels = allowedLevels ?? LogLevel.values.toSet();

  @override
  bool shouldLog(String key, LogLevel level, String message, String? prefix) {
    return allowedLevels.contains(level);
  }
}

/// 日志前缀过滤器
///
/// 通过设置允许的日志前缀来过滤日志，支持精确匹配和通配符匹配。
///
/// 示例：
/// ```dart
/// // 只记录前缀为 'API' 或 'DB' 的日志
/// final filter = PrefixLogFilter(prefixes: ['API', 'DB']);
///
/// // 排除所有以 'DEBUG' 开头的日志
/// final filter = PrefixLogFilter(excludePrefixes: ['DEBUG*']);
///
/// // 记录 'API' 开头的日志，但排除 'API:TEST'
/// final filter = PrefixLogFilter(
///   prefixes: ['API*'],
///   excludePrefixes: ['API:TEST'],
/// );
/// ```
class PrefixLogFilter implements LogFilter {
  /// 允许的日志前缀列表，为空表示不限制（除非设置了 excludePrefixes）
  /// 支持通配符 `*` 匹配任意字符，例如 `'API*'` 匹配所有以 'API' 开头的字符串
  final List<String> prefixes;

  /// 排除的日志前缀列表，优先级高于 [prefixes]
  /// 支持通配符 `*` 匹配任意字符
  final List<String> excludePrefixes;

  /// 创建日志前缀过滤器
  ///
  /// [prefixes] 允许的前缀列表
  /// [excludePrefixes] 排除的前缀列表
  const PrefixLogFilter({
    this.prefixes = const [],
    this.excludePrefixes = const [],
  });

  @override
  bool shouldLog(String key, LogLevel level, String message, String? prefix) {
    if (prefix == null) return prefixes.isEmpty;

    for (final exclude in excludePrefixes) {
      if (_matches(prefix, exclude)) return false;
    }

    if (prefixes.isEmpty) return true;

    for (final allowed in prefixes) {
      if (_matches(prefix, allowed)) return true;
    }

    return false;
  }

  /// 匹配字符串，支持通配符 `*`
  bool _matches(String value, String pattern) {
    if (pattern == '*') return true;
    if (pattern.endsWith('*')) {
      return value.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return value == pattern;
  }
}

/// 日志类型过滤器
///
/// 通过设置允许的日志键名（[TalkerKey]）来过滤日志，不在集合中的键名将被过滤。
///
/// 示例：只记录 HTTP 请求和响应日志
/// ```dart
/// final filter = TypeLogFilter(
///   allowedKeys: {TalkerKey.httpRequest, TalkerKey.httpResponse},
/// );
/// ```
class TypeLogFilter implements LogFilter {
  /// 允许记录的日志键名集合
  final Set<String> allowedKeys;

  /// 创建日志类型过滤器
  ///
  /// [allowedKeys] 允许的日志键名集合，默认为所有基础键名
  TypeLogFilter({Set<String>? allowedKeys})
    : allowedKeys =
          allowedKeys ??
          {
            TalkerKey.error,
            TalkerKey.critical,
            TalkerKey.info,
            TalkerKey.debug,
            TalkerKey.verbose,
            TalkerKey.warning,
            TalkerKey.exception,
            TalkerKey.httpError,
            TalkerKey.httpRequest,
            TalkerKey.httpResponse,
          };

  @override
  bool shouldLog(String key, LogLevel level, String message, String? prefix) {
    return allowedKeys.contains(key);
  }
}

/// 日志配置类
///
/// 用于配置 [LogUtils] 的全局行为。
///
/// 示例：
/// ```dart
/// LogUtils.init(settings: LogSettings(
///   useHistory: true,
///   maxHistoryItems: 200,
///   filters: [
///     LevelLogFilter(allowedLevels: {LogLevel.error, LogLevel.warning}),
///     PrefixLogFilter(prefixes: ['API', 'DB']),
///   ],
/// ));
/// ```
class LogSettings {
  /// 过滤器列表，日志必须通过所有过滤器才会被记录
  final List<LogFilter> filters;

  /// 是否保存日志历史
  final bool useHistory;

  /// 最大保存的日志历史条数
  final int maxHistoryItems;

  /// 是否输出到控制台
  final bool useConsoleLogs;

  /// 是否启用控制台日志颜色（解决某些终端如 iOS 控制台出现 ANSI 乱码 \x1B[0m 的问题）
  final bool enableColors;

  /// 创建日志配置
  ///
  /// [filters]          过滤器列表
  /// [useHistory]      是否保存历史，默认为 true
  /// [maxHistoryItems] 最大历史条数，默认为 1000
  /// [useConsoleLogs]  是否输出控制台，默认为 true
  /// [enableColors]    是否启用彩色日志，默认为 false
  const LogSettings({
    this.filters = const [],
    this.useHistory = true,
    this.maxHistoryItems = 1000,
    this.useConsoleLogs = true,
    this.enableColors = false,
  });

  /// 创建配置的副本，可覆盖部分字段
  LogSettings copyWith({
    List<LogFilter>? filters,
    bool? useHistory,
    int? maxHistoryItems,
    bool? useConsoleLogs,
    bool? enableColors,
  }) {
    return LogSettings(
      filters: filters ?? this.filters,
      useHistory: useHistory ?? this.useHistory,
      maxHistoryItems: maxHistoryItems ?? this.maxHistoryItems,
      useConsoleLogs: useConsoleLogs ?? this.useConsoleLogs,
      enableColors: enableColors ?? this.enableColors,
    );
  }
}

/// 日志工具类
///
/// 基于 talker 封装的统一日志工具，提供日志等级过滤、前缀过滤、键名过滤能力。
///
/// **初始化（可选，默认开箱即用）：**
/// ```dart
/// LogUtils.init(settings: LogSettings(
///   filters: [
///     LevelLogFilter(allowedLevels: {LogLevel.error, LogLevel.warning}),
///     PrefixLogFilter(prefixes: ['API', 'DB'], excludePrefixes: ['DEBUG*']),
///   ],
/// ));
/// ```
///
/// **基本使用：**
/// ```dart
/// LogUtils.d('调试信息');                                // debug 级别
/// LogUtils.i('普通信息');                                // info 级别
/// LogUtils.w('警告信息', prefix: 'AUTH');               // warning 级别，带前缀
/// LogUtils.e('错误信息');                               // error 级别
/// LogUtils.critical('严重错误');                         // critical 级别
/// LogUtils.http('GET /api/users');                       // HTTP 请求日志
/// LogUtils.httpResponse('200 OK /api/users');           // HTTP 响应日志
/// LogUtils.handle(exception, stackTrace, '上下文');      // 处理异常
/// ```
///
/// **过滤器操作：**
/// ```dart
/// LogUtils.addFilter(PrefixLogFilter(prefixes: ['API']));
/// LogUtils.removeAllFilters();
/// LogUtils.enabled = false;  // 全局禁用
/// ```
///
/// **获取 Talker 实例（用于高级操作如 TalkerScreen）：**
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => TalkerScreen(talker: LogUtils.talker),
///   ),
/// );
/// ```
class StormyLog {
  StormyLog._();

  static Talker? _talker;
  static LogSettings _settings = const LogSettings();
  static bool _enabled = true;

  /// 初始化 LogUtils
  ///
  /// [settings] 日志配置，默认为 [LogSettings]
  ///
  /// 多次调用会覆盖之前的配置。初始化后才可使用 [settings]。
  static void init({LogSettings? settings}) {
    if (settings != null) {
      _settings = settings;
    }
    _talker = _buildTalker();
  }

  static Talker _buildTalker() {
    return Talker(
      logger: TalkerLogger(
        settings: TalkerLoggerSettings(enableColors: _settings.enableColors),
      ),
      settings: TalkerSettings(
        enabled: _enabled,
        useHistory: _settings.useHistory,
        maxHistoryItems: _settings.maxHistoryItems,
        useConsoleLogs: _settings.useConsoleLogs,
      ),
    );
  }

  static void _ensureTalkerInitialized() {
    _talker ??= _buildTalker();
  }

  /// 全局启用/禁用日志
  ///
  /// 设置为 false 时，所有日志均不会被记录（即使有过滤器也不会执行）。
  static bool get enabled => _enabled;

  static set enabled(bool value) {
    _enabled = value;
    if (value) {
      _talker?.enable();
    } else {
      _talker?.disable();
    }
  }

  /// 添加过滤器
  ///
  /// [filter] 要添加的过滤器，多个过滤器会同时生效，
  ///          日志必须通过所有过滤器才会被记录。
  ///
  /// 示例：
  /// ```dart
  /// LogUtils.addFilter(LevelLogFilter(allowedLevels: {LogLevel.error}));
  /// ```
  static void addFilter(LogFilter filter) {
    _settings = _settings.copyWith(filters: [..._settings.filters, filter]);
  }

  /// 移除所有过滤器
  static void removeAllFilters() {
    _settings = _settings.copyWith(filters: []);
  }

  /// 清空日志历史
  static void clearHistory() {
    _talker?.cleanHistory();
  }

  /// 获取 Talker 实例
  ///
  /// 用于高级操作，如显示 TalkerScreen、添加自定义 observer 等。
  /// 如果尚未初始化，会自动创建一个默认实例。
  static Talker get talker {
    _ensureTalkerInitialized();
    return _talker!;
  }

  /// 获取当前配置
  static LogSettings get settings => _settings;

  /// 内部日志分发
  ///
  /// 依次经过所有过滤器过滤，通过后才调用 Talker 记录。
  static void _log(
    String message,
    String key,
    LogLevel level, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) {
    if (!_enabled) return;

    for (final filter in _settings.filters) {
      if (!filter.shouldLog(key, level, message, prefix)) return;
    }

    _ensureTalkerInitialized();
    final prefixedMessage = prefix != null ? '[$prefix] $message' : message;

    _talker!.log(prefixedMessage, logLevel: level);
  }

  /// 内部日志分发
  ///
  /// 依次经过所有过滤器过滤，通过后才调用 Talker 记录。
  static void _error(
    String message,
    String key,
    LogLevel level, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    String? prefix,
  }) {
    if (!_enabled) return;

    for (final filter in _settings.filters) {
      if (!filter.shouldLog(key, level, message, prefix)) return;
    }

    _ensureTalkerInitialized();
    final prefixedMessage = prefix != null ? '[$prefix] $message' : message;

    _talker!.error(prefixedMessage, extra, stackTrace);
  }

  /// 调试日志 [LogLevel.debug]
  static void d(
    String message, {
    String? prefix,
    Map<String, dynamic>? extra,
  }) => _log(
    message,
    TalkerKey.debug,
    LogLevel.debug,
    extra: extra,
    prefix: prefix,
  );

  /// 详细信息日志 [LogLevel.info]
  static void i(
    String message, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _log(
    message,
    TalkerKey.info,
    LogLevel.info,
    extra: extra,
    prefix: prefix,
  );

  /// 警告日志 [LogLevel.warning]
  static void w(
    String message, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _log(
    message,
    TalkerKey.warning,
    LogLevel.warning,
    extra: extra,
    prefix: prefix,
  );

  /// 错误日志 [LogLevel.error]
  static void e(
    String message, {
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _error(
    message,
    TalkerKey.error,
    LogLevel.error,
    extra: extra,
    prefix: prefix,
    stackTrace: stackTrace,
  );

  /// 严重错误日志 [LogLevel.critical]
  static void critical(
    String message, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _log(
    message,
    TalkerKey.critical,
    LogLevel.critical,
    extra: extra,
    prefix: prefix,
  );

  /// HTTP 请求日志 [TalkerKey.httpRequest]
  static void http(
    String message, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _log(
    message,
    TalkerKey.httpRequest,
    LogLevel.debug,
    extra: extra,
    prefix: prefix,
  );

  /// HTTP 响应日志 [TalkerKey.httpResponse]
  static void httpResponse(
    String message, {
    Map<String, dynamic>? extra,
    String? prefix,
  }) => _log(
    message,
    TalkerKey.httpResponse,
    LogLevel.info,
    extra: extra,
    prefix: prefix,
  );

  /// 处理异常
  ///
  /// 将异常信息记录到日志，同时支持传入上下文描述。
  ///
  /// [error]       异常对象
  /// [stackTrace]  堆栈跟踪
  /// [message]     额外的上下文描述信息
  static void handle(Object error, StackTrace stackTrace, [String? message]) {
    _ensureTalkerInitialized();
    _talker!.handle(error, stackTrace, message);
  }
}
