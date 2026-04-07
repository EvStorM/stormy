import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'config_parser.dart';
import 'dart_parser.dart';
import 'package:stormy_i18n/src/utils/logger.dart';

class ArbGenerator {
  final StormyI18nConfig config;
  final Map<String, ParsedI18nData> parsedItems;

  ArbGenerator(this.config, this.parsedItems);

  void generate() {
    final dir = Directory(config.outputDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    // 针对每个语言分别提取
    for (var locale in config.locales) {
      final arbMap = <String, dynamic>{};
      final normalizedLocale = locale.replaceAll('-', '_');

      // 如果需要主模板特定格式，添加 @@locale 标签
      arbMap['@@locale'] = normalizedLocale;

      for (var entry in parsedItems.entries) {
        final key = entry.key; // e.g., 'login_translations_title'
        final data = entry.value;

        // 提取对应语言文本
        final fieldName = normalizedLocale;
        var text = data.translations[fieldName] ?? data.translations[locale];
        if (text == null || text.isEmpty) {
          // 如果没有对应语言，报 warning
          I18nLogger.warn(
            '⚠️ 警告: Key "$key" 缺乏 "$locale" 语言的翻译文本。',
            '⚠️ Warning: Key "$key" is missing translation for locale "$locale".',
          );
          text = 'TODO_$locale'; // 兜底防止 flutter pub get 时因为缺少占位报错
        }

        arbMap[key] = text;

        // 构造 ARB Metadata (主模板才可能需要这些类型信息以强约束，但其他语言带上也不会报错，这里也可以考虑只为 default locale 生成)
        if (data.description != null || data.placeholders != null) {
          final metadata = <String, dynamic>{};
          if (data.description != null) {
            metadata['description'] = data.description;
          }
          if (data.placeholders != null && data.placeholders!.isNotEmpty) {
            metadata['placeholders'] = data.placeholders;
          }
          arbMap['@$key'] = metadata;
        }
      }

      // 直接使用标准命名格式：app_{LANG-CODE}.arb
      final finalName = 'app_$normalizedLocale.arb';

      final file = File(path.join(dir.path, finalName));
      const encoder = JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(arbMap));
      I18nLogger.success(
        '✅ 成功生成 ARB 文件: ${file.path}',
        '✅ Successfully generated ARB file: ${file.path}',
      );

      // 如果当前 Locale 包含脚本或区域，并且 config 里没有相应的 base locale，我们需要为其自动生成一个对应的 base 文件以满足 flutter gen-l10n 的要求。
      final parts = normalizedLocale.split('_');
      if (parts.length > 1) {
        final baseStr = parts[0];
        if (!config.locales.any((l) => l.replaceAll('-', '_') == baseStr)) {
          bool shouldGenerateBase = false;
          final userDefault = config.baseLocaleDefaults[baseStr]?.replaceAll(
            '-',
            '_',
          );

          if (userDefault != null) {
            // 用户显式指定了哪个是该 baseStr 的默认语言
            if (userDefault == normalizedLocale) {
              shouldGenerateBase = true;
            }
          } else {
            // 如果用户没有配置，默认使用第一个检测到的当前基础语系的变体作为回退语言。
            final firstMatchingLocale = config.locales
                .firstWhere(
                  (l) => l.replaceAll('-', '_').startsWith('${baseStr}_'),
                  orElse: () => locale,
                )
                .replaceAll('-', '_');
            if (firstMatchingLocale == normalizedLocale) {
              shouldGenerateBase = true;
            }
          }

          if (shouldGenerateBase) {
            final baseMap = Map<String, dynamic>.from(arbMap);
            baseMap['@@locale'] = baseStr;
            final baseFile = File(path.join(dir.path, 'app_$baseStr.arb'));
            baseFile.writeAsStringSync(encoder.convert(baseMap));
            I18nLogger.success(
              '✅ 自动补充 Base ARB 文件: ${baseFile.path}',
              '✅ Auto-supplemented Base ARB file: ${baseFile.path}',
            );
          }
        }
      }
    }
  }
}
