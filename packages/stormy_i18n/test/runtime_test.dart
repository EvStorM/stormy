import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_i18n/stormy_i18n.dart';

void main() {
  test(
    'runtime restores preference and persists follow-system selection',
    () async {
      Locale? saved = const Locale('en', 'US');
      final notifier = StormyI18n.localeNotifier;
      await StormyI18n.init(
        localeResolver: () async => saved,
        onSave: (value) async => saved = value,
      );
      expect(StormyI18n.currentLocale, const Locale('en', 'US'));
      await StormyI18n.changeLocale(null);
      expect(saved, isNull);
      expect(StormyI18n.currentLocale, isNull);
      expect(StormyI18n.localeNotifier, same(notifier));
    },
  );
}
