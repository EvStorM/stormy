import 'package:flutter/widgets.dart';

/// 多语言配置模型
class StormyI18nConfig {
  /// 默认语种（当本地存储中没有选择也没有跟随系统时使用，通常可为空）
  final Locale? defaultLocale;

  /// 本地化代理
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;

  /// 支持的语言列表
  final Iterable<Locale>? supportedLocales;

  /// 存储到 Storage 所使用的键值，默认取名 'stormy_app_locale'
  final String storageKey;

  /// 存储到指定的 Bucket，如不传则使用 StorageConfig 的 default bucket
  final String? storageBucket;

  const StormyI18nConfig({
    this.defaultLocale,
    this.localizationsDelegates,
    this.supportedLocales,
    this.storageKey = 'stormy_app_locale',
    this.storageBucket,
  });
}
