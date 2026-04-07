import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:stormy_i18n/src/utils/logger.dart';
import 'config_parser.dart';

class ScaffoldGenerator {
  final StormyI18nConfig config;

  ScaffoldGenerator(this.config);

  void generate() {
    final generatorPath = p.join(
      config.generatorDir,
      config.outputLocalizationFile,
    );
    final extensionDir = p.dirname(config.extensionOutput);
    final relativePath = p.relative(generatorPath, from: extensionDir);
    // 兼容不同平台的路径分隔符
    final importPath = relativePath.replaceAll(r'\', '/');

    final file = File(config.extensionOutput);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final fields = StringBuffer();
    final constructorParams = StringBuffer();

    for (var locale in config.locales) {
      final safeLocale = _toDartFieldName(locale);
      fields.writeln('  final String $safeLocale;');
      constructorParams.writeln('    required this.$safeLocale,');
    }

    final localeConstrs = StringBuffer();
    for (var localeStr in config.locales) {
      final safeName = _toDartFieldName(localeStr);
      final constr = _generateLocaleConstructor(localeStr);
      localeConstrs.writeln('  static const Locale $safeName = $constr;');
    }
    final supportedList = config.locales
        .map((l) => _toDartFieldName(l))
        .join(',\n    ');

    final content =
        '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// 此文件由 stormy_i18n 自动生成，基于您的 stormy_i18n.yaml 配置文件构建

import 'package:flutter/widgets.dart';

/// 当在您的应用中运行 `flutter pub get` 后，该类将由 flutter_localizations 原生生成
/// 请确保在 pubspec.yaml 中已开启 `generate: true`
import '$importPath';
export '$importPath';

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

  const I18nPlaceholder.intCompactLong() : this._(type: 'int', format: 'compactLong');

  const I18nPlaceholder.intCurrency({
    String? name,
    String? symbol,
    int? decimalDigits,
    String? customPattern,
  }) : this._(type: 'int', format: 'currency');

  const I18nPlaceholder.intDecimalPattern() : this._(type: 'int', format: 'decimalPattern');

  const I18nPlaceholder.intDecimalPatternDigits({
    int? decimalDigits,
  }) : this._(type: 'int', format: 'decimalPatternDigits');

  const I18nPlaceholder.intDecimalPercentPattern({
    int? decimalDigits,
  }) : this._(type: 'int', format: 'decimalPercentPattern');

  const I18nPlaceholder.intPercentPattern() : this._(type: 'int', format: 'percentPattern');

  const I18nPlaceholder.intScientificPattern() : this._(type: 'int', format: 'scientificPattern');

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
${fields.toString()}
  const I18nItem({
    this.key,
    this.description,
    this.placeholders,
${constructorParams.toString()}  });

  /// 返回所有支持的语种及文本映射，用于构建 ARB 时解析使用
  Map<String, String> get values => {
${config.locales.map((l) => "        '$l': ${_toDartFieldName(l)},").join('\n')}
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
        '未能在上下文中获取到 AppLocalizations。\\n'
        '原因分析：\\n'
        '1. context 所在的 Widget 并不在配置了 localizationsDelegates 的 MaterialApp/CupertinoApp 子树下。\\n'
        '2. 如果这发生在应用启动瞬间，表明 intl 本地化对象尚未完成系统级异步构建。\\n'
        '请避免强行从构建完整的生命周期之外获取多语言字段！',
      );
    }
    return localizations;
  }

}

/// [StormyLocales] 提供了精确的 [Locale] 定义。
/// 使用了高级本地化标志（如包含 scriptCode 与 countryCode），确保了真正的国家/地区分离及高精度匹配。
class StormyLocales {
${localeConstrs.toString()}
  static const List<Locale> supportedLocales = [
    $supportedList
  ];
}
''';

    file.writeAsStringSync(content);
    I18nLogger.info(
      '✅ 已生成基于配置的类型安全约束定义与拓展文件: ${config.extensionOutput}',
      '✅ Type-safe constraints definition and extension generated based on config: ${config.extensionOutput}',
    );
  }

  String _toDartFieldName(String locale) {
    // 替换中划线为下划线，保留原始的国家/语言代码大小写，以符合高级本地化定义（如 zh_Hans_CN）
    return locale.replaceAll('-', '_');
  }

  String _generateLocaleConstructor(String localeStr) {
    // 格式类似 zh_Hans_CN 或 zh-CN
    final parts = localeStr.replaceAll('-', '_').split('_');
    final languageCode = parts[0];
    String? scriptCode;
    String? countryCode;

    if (parts.length == 2) {
      if (parts[1].length == 4) {
        scriptCode = parts[1];
      } else {
        countryCode = parts[1];
      }
    } else if (parts.length >= 3) {
      scriptCode = parts[1];
      countryCode = parts[2];
    }

    if (scriptCode != null && countryCode != null) {
      return "Locale.fromSubtags(languageCode: '$languageCode', scriptCode: '$scriptCode', countryCode: '$countryCode')";
    } else if (scriptCode != null) {
      return "Locale.fromSubtags(languageCode: '$languageCode', scriptCode: '$scriptCode')";
    } else if (countryCode != null) {
      return "Locale.fromSubtags(languageCode: '$languageCode', countryCode: '$countryCode')";
    } else {
      return "Locale('$languageCode')";
    }
  }
}
