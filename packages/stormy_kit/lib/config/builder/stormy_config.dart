import '../models/dialog_config.dart';
import '../models/storage_config.dart';
import '../models/refresh_config.dart';
import '../models/stormy_theme_config.dart';
import '../models/i18n_config.dart';
import '../accessor/config_accessor.dart';

import 'package:flutter/widgets.dart'; // Locale needed here or we can use dart:ui
import 'package:stormy_i18n/stormy_i18n.dart';

import '../../core/network/stormy_network.dart';
import '../../core/dialog/stormy_dialog.dart';
import '../../core/storage/stormy_storage.dart';
import '../../core/refresh/stormy_refresh.dart';

/// 配置验证结果
class ConfigValidationResult {
  final bool isValid;
  final List<String> errors;

  const ConfigValidationResult._({required this.isValid, required this.errors});

  factory ConfigValidationResult.valid() {
    return const ConfigValidationResult._(isValid: true, errors: []);
  }

  factory ConfigValidationResult.invalid(List<String> errors) {
    return ConfigValidationResult._(isValid: false, errors: errors);
  }
}

/// Stormy 统一配置
/// 包含所有模块的配置
class StormyConfig {
  /// 网络配置
  StormyNetworkConfig? network;

  /// 弹窗配置
  StormyDialogConfig? dialog;

  /// 存储配置
  StormyStorageConfig? storage;

  /// 刷新配置
  StormyRefreshConfig? refresh;

  /// 主题配置
  StormyThemeConfig? theme;

  /// 国际化配置
  StormyI18nConfig? i18n;

  /// 应用配置
  Map<String, dynamic>? appConfig;

  /// SDK 配置
  Map<String, Map<String, dynamic>>? sdkConfigs;

  /// 验证配置
  ConfigValidationResult validate() {
    final errors = <String>[];

    if (network == null) {
      errors.add('network 未配置');
    } else if (network!.baseUrl.isEmpty) {
      errors.add('network.baseUrl 不能为空');
    }

    if (storage == null) {
      errors.add('storage 未配置');
    }

    return errors.isEmpty
        ? ConfigValidationResult.valid()
        : ConfigValidationResult.invalid(errors);
  }

  /// 检查是否已配置
  bool get isNetworkConfigured => network != null;
  bool get isDialogConfigured => dialog != null;
  bool get isStorageConfigured => storage != null;
  bool get isRefreshConfigured => refresh != null;
  bool get isThemeConfigured => theme != null;
  bool get isI18nConfigured => i18n != null;

  /// 应用配置到各个模块
  /// 返回应用结果
  Future<StormyConfigApplied> apply() async {
    bool networkApplied = false;
    bool dialogApplied = false;
    bool storageApplied = false;
    bool refreshApplied = false;
    bool themeApplied = false;
    bool localizationApplied = false;
    final List<String> sdkApplied = [];

    // 存储配置到全局访问器
    StormyConfigAccessor.initialize(theme: theme, i18n: i18n);

    // 应用网络配置
    if (network != null) {
      try {
        final client = StormyNetworkClient(config: network!);
        StormyConfigAccessor.setNetworkClient(client);
        networkApplied = true;
      } catch (e) {
        print('网络配置应用失败: $e');
      }
    }

    // 应用弹窗配置
    if (dialog != null) {
      try {
        StormyDialog.instance.initialize(dialog!);
        dialogApplied = true;
      } catch (e) {
        print('弹窗配置应用失败: $e');
      }
    }

    // 应用存储配置
    if (storage != null) {
      try {
        await StormyStorage.instance.initialize(
          config: storage!,
          registerAdapters: storage!.registerAdapters,
        );
        storageApplied = true;
      } catch (e) {
        print('存储配置应用失败: $e');
      }
    }

    // 应用刷新配置
    if (refresh != null) {
      try {
        StormyRefresh.instance.initialize(refresh!);
        refreshApplied = true;
      } catch (e) {
        print('刷新配置应用失败: $e');
      }
    }

    // 主题配置需要外部应用（ThemeProvider）
    if (theme != null) {
      themeApplied = true;
    }

    // 应用国际化配置
    if (i18n != null) {
      try {
        if (!storageApplied) {
          print('警告: I18n 依赖 Storage，但 Storage 未配置或应用失败');
        }

        final bucketName = (i18n!.storageBucket != null && i18n!.storageBucket!.isNotEmpty)
            ? i18n!.storageBucket!
            : StormyStorage.instance.currentBucketName;

        await StormyI18n.init(
          defaultLocale: i18n!.defaultLocale,
          localeResolver: () async {
            final data = StormyStorage.instance.bucket(bucketName).getString(i18n!.storageKey);
            if (data != null && data.isNotEmpty) {
              final parts = data.split('_');
              return Locale(parts[0], parts.length > 1 ? parts[1] : null);
            }
            return null;
          },
          onSave: (locale) async {
            if (locale == null) {
              await StormyStorage.instance.bucket(bucketName).remove(i18n!.storageKey);
            } else {
              final localeStr = locale.countryCode != null
                  ? '${locale.languageCode}_${locale.countryCode}'
                  : locale.languageCode;
              await StormyStorage.instance.bucket(bucketName).setString(i18n!.storageKey, localeStr);
            }
          },
        );
        localizationApplied = true;
      } catch (e) {
        print('国际化配置应用失败: $e');
      }
    }

    return StormyConfigApplied(
      networkApplied: networkApplied,
      dialogApplied: dialogApplied,
      storageApplied: storageApplied,
      refreshApplied: refreshApplied,
      themeApplied: themeApplied,
      localizationApplied: localizationApplied,
      sdkApplied: sdkApplied,
    );
  }
}

/// 配置构建器
/// 用于链式配置 stormy
class StormyConfigBuilder {
  final StormyConfig _config = StormyConfig();

  /// 配置网络模块
  StormyConfigBuilder network(StormyNetworkConfig config) {
    _config.network = config;
    return this;
  }

  /// 配置弹窗模块
  StormyConfigBuilder dialog(StormyDialogConfig config) {
    _config.dialog = config;
    return this;
  }

  /// 配置存储模块
  StormyConfigBuilder storage(StormyStorageConfig config) {
    _config.storage = config;
    return this;
  }

  /// 配置刷新模块
  StormyConfigBuilder refresh(StormyRefreshConfig config) {
    _config.refresh = config;
    return this;
  }

  /// 配置主题模块
  StormyConfigBuilder theme(StormyThemeConfig config) {
    _config.theme = config;
    return this;
  }

  /// 配置国际化模块
  StormyConfigBuilder i18n(StormyI18nConfig config) {
    _config.i18n = config;
    return this;
  }

  /// 配置应用模块
  StormyConfigBuilder app(Map<String, dynamic> config) {
    _config.appConfig = config;
    return this;
  }

  /// 配置 SDK
  StormyConfigBuilder sdk(String name, Map<String, dynamic>? config) {
    _config.sdkConfigs ??= {};
    _config.sdkConfigs![name] = config ?? {};
    return this;
  }

  /// 构建并验证配置
  /// [validate] 是否验证配置，默认为 true
  /// [apply] 是否自动应用到各个模块，默认为 true
  /// 返回配置对象
  Future<StormyConfig> build({bool validate = true, bool apply = true}) async {
    if (validate) {
      final result = _config.validate();
      if (!result.isValid) {
        throw ConfigurationException(result.errors.join('\n'));
      }
    }

    if (apply) {
      await _config.apply();
    }

    return _config;
  }
}

/// 配置异常
class ConfigurationException implements Exception {
  final String message;

  ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}

/// 创建 Stormy 配置构建器
StormyConfigBuilder stormy() => StormyConfigBuilder();

/// 应用配置结果
/// 用于存储配置应用后的状态
class StormyConfigApplied {
  final bool networkApplied;
  final bool dialogApplied;
  final bool storageApplied;
  final bool refreshApplied;
  final bool themeApplied;
  final bool localizationApplied;
  final List<String> sdkApplied;

  const StormyConfigApplied({
    this.networkApplied = false,
    this.dialogApplied = false,
    this.storageApplied = false,
    this.refreshApplied = false,
    this.themeApplied = false,
    this.localizationApplied = false,
    this.sdkApplied = const [],
  });

  bool get isAllApplied =>
      networkApplied &&
      storageApplied &&
      dialogApplied &&
      refreshApplied &&
      themeApplied &&
      localizationApplied;
}
