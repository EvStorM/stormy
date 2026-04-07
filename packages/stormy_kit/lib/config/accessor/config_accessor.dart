import '../config.dart';
import '../../core/network/stormy_network.dart';

/// 支持的语言枚举
enum StormyLanguage {
  /// 中文
  zhCN('zh', 'CN'),

  /// 英文
  enUS('en', 'US');

  final String languageCode;
  final String countryCode;

  const StormyLanguage(this.languageCode, this.countryCode);
}

/// Config Accessor - 配置访问器
/// 提供全局配置访问能力，core 模块可从中获取 config 设置的数据
class StormyConfigAccessor {
  StormyConfigAccessor._();

  /// 默认网络客户端 (配合 StormyConfigBuilder 使用)
  static StormyNetworkClient? _networkClient;
  static StormyNetworkClient? get networkClient => _networkClient;

  /// 主题配置
  static StormyThemeConfig? _theme;
  static StormyThemeConfig? get theme => _theme;

  /// 资产配置
  static StormyAssetsConfig? _assets;
  static StormyAssetsConfig? get assets => _assets;

  /// 当前语言环境
  static StormyLanguage _currentLanguage = StormyLanguage.zhCN;
  static StormyLanguage get currentLanguage => _currentLanguage;

  /// 是否已初始化
  static bool get isInitialized => _theme != null;

  /// 初始化配置
  /// 供 StormyConfig.apply() 调用
  static void initialize({StormyThemeConfig? theme}) {
    _theme = theme;
  }

  /// 设置主题配置
  static void setTheme(StormyThemeConfig theme) {
    _theme = theme;
  }

  /// 设置默认网络客户端
  static void setNetworkClient(StormyNetworkClient client) {
    _networkClient = client;
  }

  /// 设置当前语言环境
  /// 需在应用初始化时调用，以获取对应语言的翻译
  static void setLanguage(StormyLanguage language) {
    _currentLanguage = language;
  }

  /// 重置配置
  static void reset() {
    _theme = null;
    _currentLanguage = StormyLanguage.zhCN;
  }

  /// 获取主题色
  /// 优先使用配置的主题色，无配置则返回默认值
  static int get primaryColorValue =>
      _theme?.primaryColor?.hashCode ?? 0xFF6366F1;
}
