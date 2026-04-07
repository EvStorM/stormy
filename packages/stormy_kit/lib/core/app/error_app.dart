import 'package:flutter/material.dart';

/// 错误应用组件
/// 当应用初始化失败时显示的降级页面
///
/// WHY: 即使初始化失败也要提供一个可用的界面
/// 避免应用完全无法启动，提升用户体验
class ErrorApp extends StatelessWidget {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const ErrorApp({
    super.key,
    this.message = '应用启动失败，请重启应用',
    this.error,
    this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '错误信息: $error',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // 这里可以添加重启应用的逻辑
                    // 或者提供联系客服的入口
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
