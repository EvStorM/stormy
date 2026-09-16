import 'dart:io';

class I18nLogger {
  static final bool isZh = Platform.localeName.toLowerCase().startsWith('zh');

  static void info(String zh, [String? en]) {
    print(isZh ? zh : (en ?? zh));
  }

  static void warn(String zh, [String? en]) {
    print(isZh ? zh : (en ?? zh));
  }

  static void error(String zh, [String? en]) {
    print(isZh ? zh : (en ?? zh));
  }

  static void success(String zh, [String? en]) {
    print(isZh ? zh : (en ?? zh));
  }
}
