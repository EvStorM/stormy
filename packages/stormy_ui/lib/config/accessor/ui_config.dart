import '../models/stormy_theme_config.dart';
import '../models/assets_config.dart';
import '../models/i18n_config.dart';

enum StormyLanguage {
  /// 中文
  zhCN('zh', 'CN'),

  /// 英文
  enUS('en', 'US');

  final String languageCode;
  final String countryCode;

  const StormyLanguage(this.languageCode, this.countryCode);
}

class StormyUiConfig {
  StormyUiConfig._();
  static StormyThemeConfig? theme;
  static StormyAssetsConfig? assets;
  static StormyI18nConfig? i18n;
  static StormyLanguage currentLanguage = StormyLanguage.zhCN;
  static void reset() {
    theme = null;
    assets = null;
    i18n = null;
    currentLanguage = StormyLanguage.zhCN;
  }
}
