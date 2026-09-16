import 'dart:io';

import 'package:test/test.dart';
import 'package:stormy_i18n_generator/src/generator/config_parser.dart';
import 'package:stormy_i18n_generator/src/generator/dart_parser.dart';

void main() {
  test(
    'existing example definitions retain messages and ICU placeholders',
    () async {
      final parser = DartParser(
        StormyI18nConfig(sourceDir: '../stormy_kit/example/lib/l10n/src'),
      );
      final data = await parser.parse();
      expect(data, hasLength(5));
      expect(data['example_translations_badge']!.translations, {
        'zh_CN': '角标',
        'en_US': 'Badge',
      });
      expect(
        data['example_translations_n_wombats']!.translations['en_US'],
        '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
      );
      expect(data['example_translations_n_wombats']!.placeholders!['count'], {
        'type': 'int',
        'format': 'compact',
      });
    },
  );

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stormy_i18n_parser_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('parses analyzer 14 class and named argument nodes', () async {
    File('${tempDir.path}/translations.dart').writeAsStringSync(r'''
class PracticeTranslations {
  static const dosageWarning = I18nItem(
    key: 'dosage_warning',
    description: 'Warn about dosage',
    placeholders: {
      'count': I18nPlaceholder.intCompactCurrency(
        symbol: '¥',
        decimalDigits: 2,
      ),
    },
    zh_CN: '剂量警告',
    en_US: 'Dosage warning',
  );
}
''');

    final parser = DartParser(StormyI18nConfig(sourceDir: tempDir.path));

    final result = await parser.parse();

    expect(result, hasLength(1));
    expect(result['dosage_warning']?.translations, {
      'zh_CN': '剂量警告',
      'en_US': 'Dosage warning',
    });
    expect(result['dosage_warning']?.description, 'Warn about dosage');
    expect(result['dosage_warning']?.placeholders, {
      'count': {
        'type': 'int',
        'format': 'compactCurrency',
        'optionalParameters': {'symbol': '¥', 'decimalDigits': 2},
      },
    });
  });

  test('infers a snake-case key from the class and field names', () async {
    File('${tempDir.path}/translations.dart').writeAsStringSync(r'''
class DrugSafety {
  static const highRiskAlert = I18nItem(
    zh_CN: '高风险提醒',
    en_US: 'High-risk alert',
  );
}
''');

    final parser = DartParser(StormyI18nConfig(sourceDir: tempDir.path));

    final result = await parser.parse();

    expect(result.keys, ['drug_safety_high_risk_alert']);
  });
}
