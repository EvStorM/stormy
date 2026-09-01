import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../stormy_kit.dart';

/// 应用根组件
/// 负责应用的 UI 配置和构建
///
/// WHY: 将 UI 构建逻辑从 main.dart 中分离，使入口文件更简洁
/// 便于测试和维护应用级别的配置
class StormyApp extends StatefulWidget {
  final GoRouter router;
  final AppModel appModel;

  const StormyApp({super.key, required this.router, required this.appModel});

  @override
  State<StormyApp> createState() => _StormyAppState();
}

class _StormyAppState extends State<StormyApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize(widget.appModel);
  }

  @override
  void didUpdateWidget(covariant StormyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.appModel.preferredOrientations,
      widget.appModel.preferredOrientations,
    )) {
      _initialization = _initialize(widget.appModel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorApp(
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return _buildApplication();
      },
    );
  }

  Widget _buildApplication() {
    return ScreenUtilInit(
      designSize: widget.appModel.designSize,
      minTextAdapt: true,
      ensureScreenSize: true,
      builder: (context, child) {
        return AdaptiveTheme(
          light: StormyTheme.lightThemeData,
          dark: StormyTheme.darkThemeData,
          initial: StormyTheme.adaptiveThemeMode,
          builder: (theme, darkTheme) => ValueListenableBuilder<Locale?>(
            valueListenable: StormyI18n.localeNotifier,
            builder: (context, currentLocale, child) {
              return MaterialApp.router(
                locale: currentLocale,
                localizationsDelegates:
                    StormyConfigAccessor.i18n?.localizationsDelegates,
                supportedLocales:
                    StormyConfigAccessor.i18n?.supportedLocales ??
                    const <Locale>[Locale('en', 'US')],
                // Router 配置
                routerConfig: widget.router,
                // Theme 配置
                theme: theme,
                darkTheme: darkTheme,
                themeAnimationDuration: const Duration(milliseconds: 500),
                themeAnimationCurve: Curves.easeInOut,
                onGenerateTitle: (context) {
                  return widget.appModel.title;
                },
                // UI 配置
                debugShowCheckedModeBanner: false,
                // Smart Dialog 配置（会自动注入 navigatorObservers）
                builder: FlutterSmartDialog.init(
                  toastBuilder: widget.appModel.toastBuilder,
                  loadingBuilder: widget.appModel.loadingBuilder,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _initialize(AppModel appModel) async {
    await AppInitializer.initialize(
      orientations: appModel.preferredOrientations,
    );
    StormyTheme.initialize();
    _configureSmartDialog();
  }

  void _configureSmartDialog() {
    SmartDialog.config
      ..custom = SmartConfigCustom(
        maskColor: Colors.black.withAlpha(90),
        useAnimation: true,
      )
      ..attach = SmartConfigAttach(
        animationType: SmartAnimationType.scale,
        usePenetrate: false,
      )
      ..loading = SmartConfigLoading(
        clickMaskDismiss: false,
        leastLoadingTime: const Duration(milliseconds: 600),
      )
      ..toast = SmartConfigToast(
        intervalTime: const Duration(milliseconds: 100),
        displayTime: const Duration(milliseconds: 2000),
      );
  }
}
