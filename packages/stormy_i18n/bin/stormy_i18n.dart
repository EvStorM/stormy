#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:watcher/watcher.dart';

import 'package:path/path.dart' as path;
import 'package:stormy_i18n/src/generator/config_parser.dart';
import 'package:stormy_i18n/src/generator/scaffold_generator.dart';
import 'package:stormy_i18n/src/generator/dart_parser.dart';
import 'package:stormy_i18n/src/generator/arb_generator.dart';
import 'package:stormy_i18n/src/utils/logger.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand(
      'init',
      ArgParser()..addFlag(
        'force',
        abbr: 'f',
        help: '强制清除现有配置文件及输出产物',
        defaultsTo: false,
      ),
    )
    ..addCommand('gen')
    ..addCommand('watch');

  final results = parser.parse(args);
  final configPath = 'stormy_i18n.yaml';

  if (results.command?.name == 'init') {
    final isForce = results.command?['force'] as bool? ?? false;
    I18nLogger.info(
      '🚀 初始化 stormy_i18n 配置与脚手架代码...',
      '🚀 Initializing stormy_i18n config and scaffold code...',
    );

    if (isForce) {
      if (File(configPath).existsSync()) {
        try {
          final oldConfig = StormyI18nConfig.fromYaml(configPath);
          final outDir = Directory(oldConfig.outputDir);
          if (outDir.existsSync()) outDir.deleteSync(recursive: true);
          final genDir = Directory(oldConfig.generatorDir);
          if (genDir.existsSync()) genDir.deleteSync(recursive: true);
          final extensionFile = File(oldConfig.extensionOutput);
          if (extensionFile.existsSync()) extensionFile.deleteSync();
        } catch (_) {}
      }

      final l10nYaml = File('l10n.yaml');
      if (l10nYaml.existsSync()) l10nYaml.deleteSync();
      final stormyYaml = File(configPath);
      if (stormyYaml.existsSync()) stormyYaml.deleteSync();
      I18nLogger.info(
        '🗑️ 已清理旧的配置文件及输出产物 (--force)',
        '🗑️ Cleaned up old config and output files (--force)',
      );
    }

    final config = StormyI18nConfig.fromYaml(configPath);
    config.saveDefault(configPath);
    I18nLogger.info(
      '✅ 生成配置文件: stormy_i18n.yaml',
      '✅ Generated config file: stormy_i18n.yaml',
    );

    // 生成项目中可供使用的 I18nItem 与 BuildContext 拓展
    ScaffoldGenerator(config).generate();
    _generateExampleFile(config);

    // 初始化后自动执行一次 gen，生成基本内容避免报错
    await _runGenerate(config);
    return;
  }

  if (results.command?.name == 'watch') {
    I18nLogger.info(
      '👀 开始监听目录变化以自动生成...',
      '👀 Started watching directory changes for auto-generation...',
    );
    final file = File(configPath);
    if (!file.existsSync()) {
      I18nLogger.info(
        '❌ 未找到 stormy_i18n.yaml 配置文件，请先运行: dart run stormy_i18n init',
        '❌ Config file stormy_i18n.yaml not found, please run: dart run stormy_i18n init first',
      );
      exit(1);
    }

    var config = StormyI18nConfig.fromYaml(configPath);
    if (!config.enabled) {
      I18nLogger.info(
        '⚠️ stormy_i18n 生成已在配置中禁用。',
        '⚠️ stormy_i18n generation is disabled in config.',
      );
      return;
    }

    // 初次执行一次
    await _runGenerate(config);

    final watcher = DirectoryWatcher(config.sourceDir);
    Timer? debounceTimer;

    watcher.events.listen((event) {
      if (!event.path.endsWith('.dart')) return;

      // 添加防抖动机制，每次变动后延迟 500ms，如果是多次保存则只执行最后一次
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        I18nLogger.info(
          '\n🔄 检测到源代码更新: ${event.path}，开始重新生成...',
          '\n🔄 Detected source code update: ${event.path}, starting regeneration...',
        );
        // 重新读取配置以防止运行期间变动
        config = StormyI18nConfig.fromYaml(configPath);
        if (config.enabled) {
          await _runGenerate(config);
        }
      });
    });

    // 阻塞主线程以保持监听
    await Completer<void>().future;
    return;
  }

  if (results.command?.name == 'gen' || results.command == null) {
    I18nLogger.info(
      '🚀 开始执行 stormy_i18n ARB 生成任务...',
      '🚀 Started stormy_i18n ARB generation task...',
    );
    final file = File(configPath);
    if (!file.existsSync()) {
      I18nLogger.info(
        '❌ 未找到 stormy_i18n.yaml 配置文件，请先运行: dart run stormy_i18n init',
        '❌ Config file stormy_i18n.yaml not found, please run: dart run stormy_i18n init first',
      );
      exit(1);
    }

    final config = StormyI18nConfig.fromYaml(configPath);
    if (!config.enabled) {
      I18nLogger.info(
        '⚠️ stormy_i18n 生成已在配置中禁用。',
        '⚠️ stormy_i18n generation is disabled in config.',
      );
      return;
    }

    await _runGenerate(config);
    return;
  }
}

Future<void> _runGenerate(StormyI18nConfig config) async {
  final yamlFile = File('stormy_i18n.yaml');
  final dartFile = File(config.extensionOutput);

  if (!dartFile.existsSync() ||
      (yamlFile.existsSync() &&
          yamlFile.lastModifiedSync().isAfter(dartFile.lastModifiedSync()))) {
    I18nLogger.info(
      '🔄 检测到 stormy_i18n.yaml 有更新，重新生成 stormy_i18n.dart 文件...',
      '🔄 Detected updates in stormy_i18n.yaml, regenerating stormy_i18n.dart file...',
    );
    ScaffoldGenerator(config).generate();
  } else {
    I18nLogger.info(
      '✅ stormy_i18n.yaml 无更新，跳过 stormy_i18n.dart 生成。',
      '✅ No updates in stormy_i18n.yaml, skipping stormy_i18n.dart generation.',
    );
  }

  final dartParser = DartParser(config);
  final items = await dartParser.parse();
  if (items.isEmpty) {
    I18nLogger.info(
      'ℹ️ 未在 ${config.sourceDir} 找到任何包含 I18nItem 翻译定义的文件。',
      'ℹ️ No files containing I18nItem translation definitions found in ${config.sourceDir}.',
    );
    return;
  }

  I18nLogger.info(
    '📦 解析到 ${items.length} 个本地化属性定义。开始生成 ARB 文件...',
    '📦 Parsed ${items.length} localized property definitions. Starting ARB file generation...',
  );
  ArbGenerator(config, items).generate();

  I18nLogger.info(
    '✅ 配置 Flutter 原生本地化选项: l10n.yaml',
    '✅ Configuring Flutter native localization options: l10n.yaml',
  );
  final l10nYaml =
      '''
# 由 stormy_i18n 自动映射生成的 flutter_localizations 配置文件
arb-dir: ${config.outputDir}
template-arb-file: ${config.templateArbFile}
output-dir: ${config.generatorDir}
output-localization-file: ${config.outputLocalizationFile}
''';
  File('l10n.yaml').writeAsStringSync(l10nYaml);

  I18nLogger.info(
    '⏳ 正在自动执行 flutter gen-l10n...',
    '⏳ Automatically executing flutter gen-l10n...',
  );
  final result = await Process.run('flutter', ['gen-l10n']);
  if (result.exitCode == 0) {
    I18nLogger.info(
      '🎉 生成执行完毕! AppLocalizations 已更新。',
      '🎉 Generation completed successfully! AppLocalizations updated.',
    );
  } else {
    I18nLogger.info(
      '❌ 执行 flutter gen-l10n 失败:\n${result.stderr}',
      '❌ Failed to execute flutter gen-l10n:\n${result.stderr}',
    );
  }
}

void _generateExampleFile(StormyI18nConfig config) {
  final dir = Directory(config.sourceDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final file = File(path.join(dir.path, 'example.dart'));
  if (file.existsSync()) {
    return;
  }

  // 计算正确的 import 路径 (将反斜杠替换为正斜杠以确保跨平台兼容)
  final relativePath = path
      .relative(config.extensionOutput, from: config.sourceDir)
      .replaceAll('\\', '/');

  final sb = StringBuffer();
  sb.writeln("import '$relativePath';");
  sb.writeln();
  sb.writeln('class ExampleTranslations {');

  final Map<String, Map<String, String>> examples = {
    'badge': {'zh': "'角标'", 'en': "'Badge'", 'ja': "'バッジ'"},
    'nWombats': {
      'description': "'A plural message'",
      'zh': "'{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}'",
      'en':
          "'{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}'",
      'ja': "'{count, plural, =0{ウォンバットなし} other{{count}匹のウォンバット}}'",
      'placeholders':
          "{\n      'count': I18nPlaceholder.int(format: 'compact'),\n    }",
    },
    'pronoun': {
      'description': "'A gendered message'",
      'zh': "'{gender, select, male{他} female{她} other{他/她}}'",
      'en': "'{gender, select, male{he} female{she} other{they}}'",
      'ja': "'{gender, select, male{彼} female{彼女} other{彼ら}}'",
      'placeholders': "{\n      'gender': I18nPlaceholder.string(),\n    }",
    },
    'money': {
      'description': "'A message with a formatted int parameter'",
      'zh': "'商品价格: {value}'",
      'en': "'Price: {value}'",
      'ja': "'価格: {value}'",
      'placeholders':
          "{\n      'value': I18nPlaceholder.intCompactCurrency(\n        decimalDigits: 2,\n      ),\n    }",
    },
    'helloWorldOn': {
      'description': "'A message with a date parameter'",
      'zh':
          "'{date}:{time} 您好, {name}, {gender, select, male{他} female{她} other{他/她}}已经有{count}个未读消息'",
      'en':
          "' {name} Hello World on {date}:{time}, {gender, select, male{he} female{she} other{they}} have {count} unread {count, plural, =1{message} other{messages}}'",
      'ja':
          "'{date}:{time} こんにちは {name}, {gender, select, male{彼} female{彼女} other{彼ら}} は {count} 件の未読メッセージがあります'",
      'placeholders':
          "{\n      'date': I18nPlaceholder.dateTime(format: 'yMd'),\n      'time': I18nPlaceholder.dateTime(format: 'jm'),\n      'name': I18nPlaceholder.string(),\n      'count': I18nPlaceholder.int(format: 'compact'),\n      'gender': I18nPlaceholder.string(),\n    }",
    },
  };

  for (final entry in examples.entries) {
    final key = entry.key;
    final map = entry.value;

    sb.writeln('  static const $key = I18nItem(');
    if (map.containsKey('description')) {
      sb.writeln("    description: ${map['description']},");
    }

    for (var l in config.locales) {
      final fieldName = l.replaceAll('-', '_');
      final baseLang = l.split(RegExp(r'[_-]'))[0].toLowerCase();
      // 如果配置的语言在示例中没有直接对应的文本，则回退到基础语言或者英语
      final text = map.containsKey(l)
          ? map[l]
          : (map.containsKey(baseLang) ? map[baseLang] : map['en']);
      sb.writeln('    $fieldName: $text,');
    }

    if (map.containsKey('placeholders')) {
      sb.writeln("    placeholders: ${map['placeholders']},");
    }
    sb.writeln('  );');
    sb.writeln();
  }

  sb.writeln('}');
  file.writeAsStringSync(sb.toString());
  I18nLogger.info(
    '✅ 示例文件生成成功: ${file.path}',
    '✅ Example file generated successfully: ${file.path}',
  );
}
