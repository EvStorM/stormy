import 'package:stormy_ui/config/models/dialog_config.dart';
import 'package:stormy_core/config/models/storage_config.dart';
import 'package:stormy_ui/config/models/refresh_config.dart';
import 'package:stormy_ui/config/models/stormy_theme_config.dart';
import 'package:stormy_ui/config/models/i18n_config.dart';

import '../accessor/config_accessor.dart';

import 'package:flutter/widgets.dart'; // Locale needed here or we can use dart:ui
import 'package:stormy_i18n/stormy_i18n.dart';

import 'package:stormy_core/core/network/stormy_network.dart';
import 'package:stormy_ui/core/dialog/stormy_dialog.dart';
import 'package:stormy_core/core/storage/stormy_storage.dart';
import 'package:stormy_ui/core/refresh/stormy_refresh.dart';

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

    if (network != null && network!.baseUrl.isEmpty) {
      errors.add('network.baseUrl 不能为空');
    }

    if (storage != null) {
      final names = storage!.buckets.map((bucket) => bucket.name).toList();
      if (names.isEmpty ||
          names.toSet().length != names.length ||
          !names.contains(storage!.defaultBucketName)) {
        errors.add('storage 分区必须非空、名称唯一且包含默认分区');
      }
    }
    if (i18n != null &&
        storage == null &&
        !StormyStorage.instance.isInitialized) {
      errors.add('i18n 的语言持久化需要先配置 storage');
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
    final modules = <StormyModule, ModuleApplyResult>{};
    Future<void> applyModule(
      StormyModule module,
      Future<void> Function() action,
    ) async {
      try {
        await action();
        modules[module] = const ModuleApplyResult.applied();
      } catch (error, stackTrace) {
        modules[module] = ModuleApplyResult.failed(error, stackTrace);
      }
    }

    if (network != null) {
      await applyModule(StormyModule.network, () async {
        final client = StormyNetworkClient(config: network!);
        StormyConfigAccessor.setNetworkClient(client);
      });
    }
    if (dialog != null) {
      await applyModule(StormyModule.dialog, () async {
        StormyDialog.instance.initialize(dialog!);
      });
    }
    if (storage != null) {
      await applyModule(StormyModule.storage, () async {
        await StormyStorage.instance.initialize(
          config: storage!,
          registerAdapters: storage!.registerAdapters,
          engine: storage!.engine,
        );
      });
    }
    if (refresh != null) {
      await applyModule(StormyModule.refresh, () async {
        StormyRefresh.instance.initialize(refresh!);
      });
    }
    if (theme != null) {
      await applyModule(StormyModule.theme, () async {
        StormyConfigAccessor.setTheme(theme!);
      });
    }
    if (i18n != null) {
      await applyModule(StormyModule.i18n, () async {
        if (modules[StormyModule.storage]?.error != null ||
            !StormyStorage.instance.isInitialized) {
          throw StateError('i18n 依赖的 storage 未初始化成功');
        }
        final config = i18n!;
        final bucketName = config.storageBucket?.isNotEmpty == true
            ? config.storageBucket!
            : StormyStorage.instance.currentBucketName;
        final bucket = StormyStorage.instance.bucket(bucketName);
        await StormyI18n.init(
          defaultLocale: config.defaultLocale,
          localeResolver: () async {
            final data = bucket.getString(config.storageKey);
            if (data == null || data.isEmpty) return null;
            final parts = data.split('_');
            return Locale.fromSubtags(
              languageCode: parts[0],
              scriptCode: parts.length > 1 && parts[1].length == 4
                  ? parts[1]
                  : null,
              countryCode: parts.length > 2
                  ? parts[2]
                  : parts.length > 1 && parts[1].length != 4
                  ? parts[1]
                  : null,
            );
          },
          onSave: (locale) async {
            if (locale == null) {
              await bucket.remove(config.storageKey);
            } else {
              await bucket.setString(config.storageKey, locale.toString());
            }
          },
        );
        StormyConfigAccessor.setI18n(config);
      });
    }
    return StormyConfigApplied(modules);
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
      final report = await _config.apply();
      if (!report.isAllApplied) throw StormyInitializationException(report);
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

enum StormyModule { network, dialog, storage, refresh, theme, i18n }

class ModuleApplyResult {
  final Object? error;
  final StackTrace? stackTrace;
  const ModuleApplyResult.applied() : error = null, stackTrace = null;
  const ModuleApplyResult.failed(this.error, this.stackTrace);
  bool get isApplied => error == null;
}

/// Only configured modules are included; absent modules do not count as failures.
class StormyConfigApplied {
  final Map<StormyModule, ModuleApplyResult> modules;
  StormyConfigApplied(Map<StormyModule, ModuleApplyResult> modules)
    : modules = Map.unmodifiable(modules);
  bool _applied(StormyModule module) => modules[module]?.isApplied ?? false;
  bool get networkApplied => _applied(StormyModule.network);
  bool get dialogApplied => _applied(StormyModule.dialog);
  bool get storageApplied => _applied(StormyModule.storage);
  bool get refreshApplied => _applied(StormyModule.refresh);
  bool get themeApplied => _applied(StormyModule.theme);
  bool get localizationApplied => _applied(StormyModule.i18n);
  List<String> get sdkApplied => const [];
  bool get isAllApplied => modules.values.every((result) => result.isApplied);
}

class StormyInitializationException implements Exception {
  final StormyConfigApplied report;
  const StormyInitializationException(this.report);
  @override
  String toString() =>
      'StormyInitializationException: ${report.modules.entries.where((e) => !e.value.isApplied).map((e) => '${e.key.name}: ${e.value.error}').join('; ')}';
}
