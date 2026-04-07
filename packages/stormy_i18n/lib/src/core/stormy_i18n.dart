import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';

/// 回调类型：用于从本地持久化中读取语种代码（如 返回 Locale('zh', 'CN')，为 null 表示跟随系统）
typedef LocaleResolver = Future<Locale?> Function();

/// 回调类型：用于将新的语种代码写入本地持久化
typedef LocaleSaver = Future<void> Function(Locale? locale);

/// Stormy 多语言核心调度与状态管理器
class StormyI18n {
  const StormyI18n._();

  static final ValueNotifier<Locale?> _localeNotifier = ValueNotifier(null);

  /// 供 MaterialApp.locale 绑定以驱动全局语言变更。
  /// 如果其 value 为 null，代表当前未手动干预，完全“跟随系统”。
  static ValueNotifier<Locale?> get localeNotifier => _localeNotifier;

  static LocaleSaver? _onSave;

  /// 初始化多语言状态机。
  ///
  /// [localeResolver]: 用于从应用侧存储（如 SharedPreferences / Hive）中提取上一次的语言偏好，并还原为 Locale 对象。
  /// [onSave]: 用于切换语言后，向应用侧触发持久化保存事件。
  static Future<void> init({
    LocaleResolver? localeResolver,
    LocaleSaver? onSave,
    Locale? defaultLocale,
  }) async {
    _onSave = onSave;
    Locale? resolvedLocale;
    if (localeResolver != null) {
      resolvedLocale = await localeResolver();
    }

    // 如果本地缓存没有返回，则优先使用传入的默认语言
    // 如果没有配置默认语言，则回退为系统的首选语言
    _localeNotifier.value =
        resolvedLocale ?? defaultLocale ?? PlatformDispatcher.instance.locale;
  }

  /// 切换到指定的语种。
  ///
  /// 传入指定的 [locale] 则切换为该语种（例如 Locale('zh', 'CN')）。
  /// 传入 `null` 则清空偏好，重置为系统的首选语言（跟随系统）。
  static Future<void> changeLocale(Locale? locale) async {
    _localeNotifier.value = locale;
    if (_onSave != null) {
      await _onSave!(locale);
    }
  }

  /// 当前被显式固定的语言（如果为 null 则是跟随系统）
  static Locale? get currentLocale => _localeNotifier.value;
}
