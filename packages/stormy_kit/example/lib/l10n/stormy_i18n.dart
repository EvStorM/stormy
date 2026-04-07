// GENERATED CODE - DO NOT MODIFY BY HAND
// 此文件由 stormy_i18n 自动生成，基于您的 stormy_i18n.yaml 配置文件构建

import 'package:flutter/widgets.dart';

/// 当在您的应用中运行 `flutter pub get` 后，该类将由 flutter_localizations 原生生成
/// 请确保在 pubspec.yaml 中已开启 `generate: true`
import 'generator/app_localizations.dart';
export 'generator/app_localizations.dart';

/// 占位符定义，用于在 dart 端进行简单的配置，导出到 ARB 时将被解析
class I18nPlaceholder {
  final String type;
  final String? format;
  final Map<String, dynamic>? optionalParameters;

  const I18nPlaceholder._({
    required this.type,
    this.format,
    this.optionalParameters,
  });

  /// String 类型占位符
  const I18nPlaceholder.string() : this._(type: 'String');

  /// int 类型占位符，支持自定义格式化或者回退
  const I18nPlaceholder.int({
    String? format,
    Map<String, dynamic>? optionalParameters,
  }) : this._(
          type: 'int',
          format: format,
          optionalParameters: optionalParameters,
        );

  const I18nPlaceholder.intCompact() : this._(type: 'int', format: 'compact');

  const I18nPlaceholder.intCompactCurrency({
    String? name,
    String? symbol,
    int? decimalDigits,
  }) : this._(type: 'int', format: 'compactCurrency');

  const I18nPlaceholder.intCompactSimpleCurrency({
    String? name,
    int? decimalDigits,
  }) : this._(type: 'int', format: 'compactSimpleCurrency');

  const I18nPlaceholder.intCompactLong()
      : this._(type: 'int', format: 'compactLong');

  const I18nPlaceholder.intCurrency({
    String? name,
    String? symbol,
    int? decimalDigits,
    String? customPattern,
  }) : this._(type: 'int', format: 'currency');

  const I18nPlaceholder.intDecimalPattern()
      : this._(type: 'int', format: 'decimalPattern');

  const I18nPlaceholder.intDecimalPatternDigits({
    int? decimalDigits,
  }) : this._(type: 'int', format: 'decimalPatternDigits');

  const I18nPlaceholder.intDecimalPercentPattern({
    int? decimalDigits,
  }) : this._(type: 'int', format: 'decimalPercentPattern');

  const I18nPlaceholder.intPercentPattern()
      : this._(type: 'int', format: 'percentPattern');

  const I18nPlaceholder.intScientificPattern()
      : this._(type: 'int', format: 'scientificPattern');

  const I18nPlaceholder.intSimpleCurrency({
    String? name,
    int? decimalDigits,
  }) : this._(type: 'int', format: 'simpleCurrency');

  /// DateTime 类型占位符，支持日期格式化
  const I18nPlaceholder.dateTime({
    String? format,
  }) : this._(
          type: 'DateTime',
          format: format,
        );
}

/// 用于类型安全约束的按配置生成的多语言项定义
class I18nItem {
  final String? key;
  final String? description;
  final Map<String, I18nPlaceholder>? placeholders;
  final String zhCN;
  final String enUS;

  const I18nItem({
    this.key,
    this.description,
    this.placeholders,
    required this.zhCN,
    required this.enUS,
  });

  /// 返回所有支持的语种及文本映射，用于构建 ARB 时解析使用
  Map<String, String> get values => {
        'zh_CN': zhCN,
        'en_US': enUS,
      };
}

/// 提供全量代码提示与安全返回 AppLocalizations 的上下文拓展
extension StormyL10nExtension on BuildContext {
  /// 获取当前应用的本地化字典。
  /// 如果在调用时抛出 `FlutterError`，说明您的代码在 MaterialApp 的上下文中未正确生命周期初始化完毕。
  AppLocalizations get l10n {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw FlutterError(
        '未能在上下文中获取到 AppLocalizations。\n'
        '原因分析：\n'
        '1. context 所在的 Widget 并不在配置了 localizationsDelegates 的 MaterialApp/CupertinoApp 子树下。\n'
        '2. 如果这发生在应用启动瞬间，表明 intl 本地化对象尚未完成系统级异步构建。\n'
        '请避免强行从构建完整的生命周期之外获取多语言字段！',
      );
    }
    return localizations;
  }
}

/// [StormyLocales] 提供了精确的 [Locale] 定义。
/// 使用了高级本地化标志（如包含 scriptCode 与 countryCode），确保了真正的国家/地区分离及高精度匹配。
class StormyLocales {
  static const Locale zhCN =
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN');
  static const Locale enUS =
      Locale.fromSubtags(languageCode: 'en', countryCode: 'US');

  static const List<Locale> supportedLocales = [zhCN, enUS];
}
