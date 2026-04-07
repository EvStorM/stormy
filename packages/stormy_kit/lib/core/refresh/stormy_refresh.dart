import '../../config/models/refresh_config.dart';

/// Stormy 刷新模块管理器
/// 用于管理刷新配置
class StormyRefresh {
  StormyRefresh._();

  /// 单例实例
  static final StormyRefresh instance = StormyRefresh._();

  /// 当前刷新配置
  StormyRefreshConfig? _config;

  /// 获取当前配置，如果没有显式初始化则返回默认配置
  static StormyRefreshConfig get config {
    return instance._config ?? StormyRefreshConfig.defaultConfig();
  }

  /// 获取原始配置数据 (可为空)
  StormyRefreshConfig? get rawConfig => _config;

  /// 是否已初始化
  bool get isInitialized => _config != null;

  /// 初始化刷新配置
  void initialize(StormyRefreshConfig config) {
    _config = config;
  }

  /// 重置配置
  void reset() {
    _config = null;
  }
}
