import 'package:stormy_core/stormy_core.dart';
import 'package:stormy_ui/stormy_ui.dart';
export 'package:stormy_ui/config/accessor/ui_config.dart' show StormyLanguage;

/// Compatibility facade. State belongs to core and UI respectively.
class StormyConfigAccessor {
  StormyConfigAccessor._();
  static StormyNetworkClient? get networkClient => StormyServices.networkClient;
  static StormyThemeConfig? get theme => StormyUiConfig.theme;
  static StormyAssetsConfig? get assets => StormyUiConfig.assets;
  static StormyI18nConfig? get i18n => StormyUiConfig.i18n;
  static StormyLanguage get currentLanguage => StormyUiConfig.currentLanguage;
  static bool get isInitialized => theme != null;
  static void initialize({StormyThemeConfig? theme, StormyI18nConfig? i18n}) {
    StormyUiConfig.theme = theme;
    StormyUiConfig.i18n = i18n;
  }

  static void setI18n(StormyI18nConfig config) => StormyUiConfig.i18n = config;
  static void setTheme(StormyThemeConfig config) =>
      StormyUiConfig.theme = config;
  static void setNetworkClient(StormyNetworkClient client) =>
      StormyServices.networkClient = client;
  static void setLanguage(StormyLanguage language) =>
      StormyUiConfig.currentLanguage = language;
  static int get primaryColorValue =>
      theme?.primaryColor?.toARGB32() ?? 0xFF6366F1;
  static void reset() {
    StormyUiConfig.reset();
    StormyServices.reset();
  }
}
