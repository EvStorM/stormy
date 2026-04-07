import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import '../../stormy_kit.dart';

/// 应用根组件
/// 负责应用的 UI 配置和构建
///
/// WHY: 将 UI 构建逻辑从 main.dart 中分离，使入口文件更简洁
/// 便于测试和维护应用级别的配置
class StormyApp extends HookWidget {
  final GoRouter router;
  final AppModel appModel;
  const StormyApp({super.key, required this.router, required this.appModel});
  @override
  Widget build(BuildContext context) {
    // 使用 useState 确保主题只初始化一次
    final isThemeInitialized = useState(false);
    // 初始化主题（使用 useEffect 避免在 build 期间触发状态更新）
    _initTheme(isThemeInitialized);
    return ScreenUtilInit(
      designSize: AppModel.defaults().designSize,
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
                localizationsDelegates: StormyConfigAccessor.i18n?.localizationsDelegates,
                supportedLocales: StormyConfigAccessor.i18n?.supportedLocales ?? const <Locale>[Locale('en', 'US')],
                // Router 配置
                routerConfig: router,
                // Theme 配置
                theme: theme,
                darkTheme: darkTheme,
                themeAnimationDuration: const Duration(milliseconds: 500),
                themeAnimationCurve: Curves.easeInOut,
                onGenerateTitle: (context) {
                  return appModel.title;
                },
                // UI 配置
                debugShowCheckedModeBanner: false,
                // Smart Dialog 配置（会自动注入 navigatorObservers）
                builder: FlutterSmartDialog.init(
                  toastBuilder: appModel.toastBuilder,
                  loadingBuilder: appModel.loadingBuilder,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 初始化应用主题
  ///
  /// WHY: 使用 useEffect 在组件挂载后初始化主题
  /// 避免在 build 过程中触发状态更新
  void _initTheme(ValueNotifier<bool> isThemeInitialized) {
    useEffect(() {
      if (!isThemeInitialized.value) {
        AppInitializer.initialize();
        // 延迟到下一帧执行，确保 ScreenUtilInit 已完成初始化
        WidgetsBinding.instance.addPostFrameCallback((_) {
          StormyTheme.initialize();
          isThemeInitialized.value = true;
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
        });
      }
      return null;
    }, []);
  }
}
