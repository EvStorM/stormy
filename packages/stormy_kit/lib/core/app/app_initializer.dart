import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// 应用基础初始化器
/// 负责 Flutter 框架层面的基础初始化
/// 这些初始化逻辑是通用的，可以在不同项目中复用
class AppInitializer {
  /// 初始化 Flutter 绑定
  /// 确保在调用任何 Flutter 功能之前完成绑定初始化
  static void ensureFlutterBinding() {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// 配置 debugPrint 输出
  /// 确保在 iOS 调试时也能看到日志输出
  /// WHY: iOS 上 debugPrint 默认输出可能被 Xcode 过滤，需要配置以确保可见性
  static void configureDebugPrint() {
    if (kDebugMode) {
      // 在 Debug 模式下，使用 print 函数确保 iOS 上也能看到输出
      // 同时保留 debugPrint 的节流功能，避免日志过多
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          // 使用 developer.log 确保在 iOS Xcode 控制台中可见
          developer.log(
            message,
            name: 'Flutter',
            level: 800, // 自定义日志级别
          );
          // 同时使用 print 作为备用，确保在终端中也能看到
          // print(message);
        }
      };
    }
  }

  /// 设置屏幕方向
  /// [orientations] 允许的屏幕方向列表
  static Future<void> setScreenOrientation({
    List<DeviceOrientation> orientations = const [DeviceOrientation.portraitUp],
  }) async {
    await SystemChrome.setPreferredOrientations(orientations);
  }

  /// 设置高刷新率
  /// 在支持的设备上启用高刷新率显示
  static Future<void> setHighRefreshRate() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('设置高刷新率失败: $e');
    }
  }

  /// 执行所有基础初始化
  /// 按照依赖顺序执行各项初始化任务
  static Future<void> initialize() async {
    // 初始化 Flutter 绑定
    ensureFlutterBinding();

    // 配置 debugPrint 输出（必须在绑定初始化之后）
    // configureDebugPrint();

    // 设置屏幕方向（仅支持竖屏）
    setScreenOrientation();

    // 设置高刷新率
    // setHighRefreshRate();
  }
}
