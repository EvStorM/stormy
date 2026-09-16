# 预加载

入口为 `package:stormy_core/stormy_core.dart`，旧 kit 主入口继续重导出。

Provider 任务支持同步值、Future 和 AsyncValue。只有数据就绪才计为成功；错误、超时和取消均结束当前等待。依赖使用任务 ID；必需任务失败后后续层停止，未运行任务记为取消。可选任务失败返回 partialSuccess，业务应查看失败详情。

```dart
import 'package:stormy_core/stormy_core.dart';

Future<int> preloadCount() async {
  final container = ProviderContainer();
  final tracker = PreloadTracker();
  final provider = FutureProvider<int>((ref) async => 42);
  final subscription = tracker.stream.listen((progress) {
    StormyLog.i('预加载 ${progress.progressPercentage}');
  });
  try {
    final engine = PreloadEngine(
      config: const PreloadConfig(enableLogging: false),
      tracker: tracker,
    );
    final result = await engine.execute([
      PreloadTask(id: 'count', provider: provider),
    ], container: container);
    if (!result.isCompleteSuccess) {
      throw StateError(result.failedTaskDetails.toString());
    }
    return container.read(provider).requireValue;
  } finally {
    await subscription.cancel();
    tracker.dispose();
    container.dispose();
  }
}
```

外部 ProviderContainer 在执行后仍可使用，由调用方释放；未传入时引擎创建并释放自己的容器。应用希望缓存继续供 UI 使用时，应传入 UI 使用的同一个容器。

`PreloadProgress.completedTasks` 表示成功数，`failedTasks` 表示失败数，`cancelledTasks` 表示取消或因依赖失败而未执行的任务数。`progress` 为已结束任务占比，终态为 1；成功率请用执行结果的 `successRate`。耗时在 `PreloadExecutionResult.executionTime`，进度对象不提供同名字段。

`engine.cancel()` 或 `PreloadManager.instance.cancel()` 取消当前执行，每个重试等待独立结束。Dart 普通 Future 不支持强制取消底层操作，业务网络或 IO 应自行提供取消能力。需要重新执行时先等待当前 execute 结束。

应用也可使用 `PreloadManager.instance.register(target, name: 'id', dependencies: ['other'])` 注册。只接受 ProviderListenable 或 Future<void> Function()；任务 ID 唯一，不能并行执行同一个引擎。任务级 timeout 与检查重试参数见 PreloadTask/TaskConfig，整体配置见 PreloadConfig。

行为迁移见 [迁移说明](../../../../../docs/MIGRATION.md)。

