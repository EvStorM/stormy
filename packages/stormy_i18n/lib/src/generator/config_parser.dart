import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:stormy_i18n/src/utils/logger.dart';

class StormyI18nConfig {
  final bool enabled;
  final String sourceDir;
  final String outputDir;
  final String generatorDir;
  final String extensionOutput;
  final String templateArbFile;
  final String outputLocalizationFile;
  final List<String> locales;
  final Map<String, String> baseLocaleDefaults;

  StormyI18nConfig({
    this.enabled = true,
    this.sourceDir = 'lib/l10n/src',
    this.outputDir = 'lib/l10n/arb',
    this.generatorDir = 'lib/l10n/generator',
    this.extensionOutput = 'lib/l10n/stormy_i18n.dart',
    this.templateArbFile = 'app_zh_CN.arb',
    this.outputLocalizationFile = 'app_localizations.dart',
    this.locales = const ['zh_CN', 'en_US'],
    this.baseLocaleDefaults = const {},
  });

  static StormyI18nConfig fromYaml(String path) {
    final file = File(path);
    if (!file.existsSync()) return StormyI18nConfig();

    try {
      final content = file.readAsStringSync();
      final doc = loadYaml(content) as Map;

      final enabled = doc['enabled'] as bool? ?? true;
      final sourceDir = doc['source_dir'] as String? ?? 'lib/l10n/src';
      final outputDir = doc['output_dir'] as String? ?? 'lib/l10n/arb';
      final generatorDir =
          doc['generator_dir'] as String? ?? 'lib/l10n/generator';
      final extensionOutput =
          doc['extension_output'] as String? ?? 'lib/l10n/stormy_i18n.dart';
      final templateArbFile =
          doc['template_arb_file'] as String? ?? 'app_zh_CN.arb';
      final outputLocalizationFile =
          doc['output_localization_file'] as String? ??
          'app_localizations.dart';

      final localesDynamic = doc['locales'] as YamlList?;
      final locales =
          localesDynamic?.map((e) => e.toString()).toList() ??
          ['zh_CN', 'en_US'];

      final baseLocaleDefaultsNode = doc['base_locale_defaults'] as YamlMap?;
      final baseLocaleDefaults = <String, String>{};
      if (baseLocaleDefaultsNode != null) {
        for (var entry in baseLocaleDefaultsNode.entries) {
          baseLocaleDefaults[entry.key.toString()] = entry.value.toString();
        }
      }

      return StormyI18nConfig(
        enabled: enabled,
        sourceDir: sourceDir,
        outputDir: outputDir,
        generatorDir: generatorDir,
        extensionOutput: extensionOutput,
        templateArbFile: templateArbFile,
        outputLocalizationFile: outputLocalizationFile,
        locales: locales,
        baseLocaleDefaults: baseLocaleDefaults,
      );
    } catch (e) {
      I18nLogger.warn(
        '⚠️ 无法解析 $path，使用默认配置: $e',
        '⚠️ Unable to parse $path, using default config: $e',
      );
      return StormyI18nConfig();
    }
  }

  void saveDefault(String path) {
    final file = File(path);
    if (file.existsSync()) return;

    final content = '''
# Stormy I18n 配置文件
# 是否启用代码生成
enabled: true

# 翻译源文件（Dart 语言）存放目录
source_dir: lib/l10n/src

# 最终生成的 ARB 文件存放目录
output_dir: lib/l10n/arb

# 自动生成的多语言原生代码存放目录
generator_dir: lib/l10n/generator

# 拓展帮助类（包含 I18nItem 与 context.l10n）生成的路径
# 这个文件将随工具产生，供项目中统一 import
extension_output: lib/l10n/stormy_i18n.dart

# Flutter 原生本地化的主模板文件名 (取决于你的默认语言)
template_arb_file: app_zh_CN.arb

# 自动生成的多语言类名 (原生的 flutter_localizations 生成文件名)
output_localization_file: app_localizations.dart

# 支持的地区语言标识列表 (例如 zh_CN, en_US)
# 当增加新语言时，在此处添加，并重新运行 dart run stormy_i18n gen
locales:
  - zh_CN
  - en_US

# 为基础语言指定默认的地区变体，用于自动生成满足原生系统回退要求的 Base ARB 文件。
# 例如，指定 zh 的默认语言为 zh_CN
# base_locale_defaults:
#   zh: zh_CN
#   en: en_US
''';
    file.writeAsStringSync(content);
  }
}
