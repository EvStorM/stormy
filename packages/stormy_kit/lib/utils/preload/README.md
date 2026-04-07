# Preload 预加载模块使用文档

> 适用于 Stormy 应用中的 `utils/preload` 模块
> 最后更新：2026-03-27

---

## 目录

1. [模块概述](#1-模块概述)
2. [核心概念](#2-核心概念)
3. [快速开始](#3-快速开始)
4. [API 详解](#4-api-详解)
   - [PreloadManager](#41-preloadmanager)
   - [PreloadConfig](#42-preloadconfig)
   - [PreloadTask 与 TaskConfig](#43-preloadtask--taskconfig)
   - [PreloadProgress](#44-preloadprogress)
   - [PreloadExecutionResult](#45-preloadexecutionresult)
   - [状态枚举](#46-状态枚举)
5. [进阶用法](#5-进阶用法)
6. [架构设计](#6-架构设计)
7. [异常处理](#7-异常处理)
8. [最佳实践](#8-最佳实践)
9. [常见问题](#9-常见问题)

---

## 1. 模块概述

`utils/preload` 是 Stormy 应用中的**统一预加载管理模块**，基于 Riverpod 构建，采用 Facade 模式对外提供简洁的 API。模块负责在应用启动阶段批量加载 Provider 数据、执行异步初始化任务，并提供完善的依赖管理、并发控制、进度追踪和错误处理能力。

### 核心能力

- **Provider 预加载**：自动触发 Riverpod Provider 的初始化，支持 `FutureProvider`、`StreamProvider`、`AsyncNotifier` 等类型。
- **异步方法预加载**：支持直接传入 `Future<void> Function()` 异步函数，灵活处理非 Riverpod 的初始化逻辑（如数据库初始化、SDK 初始化）。
- **智能依赖解析**：通过 Kahn 拓扑排序自动解析任务间的依赖关系，支持跨类型依赖（Provider 任务和方法任务可以相互依赖）。
- **并发控制**：基于信号量（Semaphore）模式精确限制最大并发数，避免资源竞争。
- **双重检查机制**：支持任务级和全局级 `checkBeforeExecute` 前置条件检查，可配置重试策略。
- **指数退避重试**：任务执行失败时自动重试，采用指数退避策略避免频繁重试。
- **实时进度追踪**：提供去抖动的进度流（Stream），包含完成百分比、正在运行的任务数、预计剩余时间等。
- **层级并行执行**：根据依赖关系将任务划分为多个层级，同一层级内的任务可并发执行，最大化利用等待时间。

### 模块文件结构

```
utils/preload/
├── preload.dart                        # 模块导出入口
├── preload_manager.dart                # Facade 入口，管理任务注册与执行
├── config/
│   └── preload_config.dart             # 全局配置
├── model/
│   ├── preload_task.dart                # 任务模型 + TaskConfig
│   ├── preload_progress.dart            # 进度信息模型
│   └── preload_result.dart              # 执行结果模型
├── engine/
│   ├── preload_engine.dart              # 核心执行引擎
│   ├── dependency_graph.dart            # 依赖分析器（拓扑排序 + 循环检测）
│   └── task_execution_context.dart       # 单任务执行上下文
├── tracker/
│   └── preload_tracker.dart             # 进度追踪器
├── control/
│   └── preload_semaphore.dart           # 并发信号量
├── state/
│   └── preload_state.dart               # 状态枚举定义
└── exception/
    └── preload_exception.dart           # 异常定义
```

---

## 2. 核心概念

### 2.1 两种任务类型

预加载模块支持两种任务类型：

| 类型 | 传入方式 | 执行方式 | 适用场景 |
|------|----------|----------|----------|
| **Provider 任务** | 直接传入 `ProviderListenable<T>` | 通过 `container.read(provider)` 触发 | 加载状态、配置数据、网络数据等 Riverpod 管理的资源 |
| **方法任务** | 传入 `Future<void> Function()` | 直接调用异步函数 | 数据库初始化、SDK 初始化、文件系统检查等非 Riverpod 逻辑 |

### 2.2 依赖层级与并行

依赖关系通过字符串 ID 声明。例如：

```
A (no deps)     → Level 0 (最先执行)
├─ B (dep A)    → Level 1 (A 完成后执行)
└─ C (dep A)    → Level 1 (与 B 并行)
   └─ D (dep B) → Level 2 (B 完成后执行)
```

同层级的任务**并发执行**，不同层级的任务**按拓扑顺序串行**。这种设计确保了依赖关系被严格遵守的同时，最大化了并行度。

### 2.3 必需任务 vs 可选任务

- **必需任务（`required: true`）**：失败会导致整个预加载流程失败，同步取消所有正在等待的任务。
- **可选任务（`required: false`）**：失败不影响其他任务和整体结果，仅记录到 `failedTaskDetails` 中。

### 2.4 执行前检查（Check）

执行前检查是一种前置条件验证机制，返回 `true` 表示可以执行，返回 `false` 表示条件未就绪，等待后重试。这不同于重试机制——**检查解决的是"能不能执行"的问题，重试解决的是"执行失败了要不要再试"的问题**。

典型应用场景：
- 检查网络是否可达（`checkBeforeExecute: () => connectivityCheck()`）
- 检查数据库连接池是否就绪
- 检查设备是否处于特定状态

---

## 3. 快速开始

### 3.1 最简用法（仅 Provider）

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/preload/utils/preload/preload.dart';

// 假设存在这些 Provider
final userProvider = FutureProvider<User>((ref) async { /* ... */ });
final configProvider = FutureProvider<AppConfig>((ref) async { /* ... */ });
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(/* ... */);

class App extends ConsumerStatefulWidget {
  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preload();
  }

  Future<void> _preload() async {
    final result = await PreloadManager.instance
        .register(userProvider, name: 'user-data')
        .register(configProvider, name: 'app-config')
        .register(themeProvider, name: 'theme-init')
        .execute();

    if (result.isCompleteSuccess) {
      setState(() => _isLoading = false);
    } else {
      // 处理失败
      debugPrint('预加载部分失败: ${result.failedTaskDetails}');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const MyHomePage();
  }
}
```

### 3.2 带依赖链的用法

```dart
await PreloadManager.instance
    // Level 0: 无依赖，最先执行
    .register(dbInitProvider, name: 'db-init')

    // Level 1: 依赖 db-init，等 db-init 完成后执行
    .register(
      userRepoProvider,
      name: 'user-repo',
      dependencies: ['db-init'],
    )
    .register(
      cacheProvider,
      name: 'cache',
      dependencies: ['db-init'],
    )

    // Level 2: 依赖 user-repo 和 cache
    .register(
      feedProvider,
      name: 'feed',
      dependencies: ['user-repo', 'cache'],
      priority: 2,  // 同层级内优先级更高
    )

    .execute();
```

### 3.3 方法任务 + 执行前检查

```dart
await PreloadManager.instance
    .register(
      () async {
        final db = await Database.open('app.db');
        await db.migrate();
      },
      name: 'db-init',
    )
    .register(
      () async {
        final cache = await Cache.connect();
        await cache.warmUp();
      },
      name: 'cache-init',
      dependencies: ['db-init'],  // 跨类型依赖
    )
    .register(
      () async {
        await NetworkChecker.ensureConnected();
        final response = await ApiClient.instance.ping();
        if (!response.ok) throw Exception('API 不可达');
      },
      name: 'api-check',
      checkBeforeExecute: () async {
        // 先检查设备是否联网
        final connectivity = await Connectivity().checkConnectivity();
        return connectivity != ConnectivityResult.none;
      },
      checkRetryDelay: const Duration(seconds: 2),
      maxCheckRetries: 5,
    )
    .execute();
```

### 3.4 监听进度

```dart
@override
void initState() {
  super.initState();
  _subscribeToProgress();
}

void _subscribeToProgress() {
  PreloadManager.instance.progress.listen((progress) {
    debugPrint('预加载进度: ${progress.progressPercentage} '
        '(${progress.completedTasks}/${progress.totalTasks})');

    if (progress.isCompleted) {
      debugPrint('预计总耗时: ${progress.executionTime?.inMilliseconds}ms');
    }

    if (progress.failedTasks > 0) {
      debugPrint('失败任务: ${progress.failedTasksDetails}');
    }
  });
}
```

### 3.5 完整配置示例

```dart
PreloadManager.instance.configure(PreloadConfig(
  maxConcurrentTasks: 4,
  defaultTimeout: const Duration(seconds: 60),
  maxRetries: 3,
  retryBaseDelay: const Duration(milliseconds: 1000),
  enableLogging: true,
  onError: (error, stackTrace) {
    // 上报错误到监控服务
    Analytics.track('preload_error', parameters: {
      'error': error.toString(),
    });
  },
  // 全局检查：所有任务执行前都会先过这个检查
  globalCheck: () async {
    // 例如：检查 App 是否在前台
    return AppLifecycleListener.state == AppLifecycleState.resumed;
  },
  globalCheckRetryDelay: const Duration(seconds: 1),
  globalCheckMaxRetries: 5,
));

await PreloadManager.instance
    .register(userProvider, name: 'user', priority: 3)
    .register(configProvider, name: 'config', priority: 2)
    .register(
      () async { await SomeService.init(); },
      name: 'service-init',
      priority: 1,
      required: false,  // 可选任务，失败不阻塞
      timeout: const Duration(seconds: 30),
    )
    .execute();
```

---

## 4. API 详解

### 4.1 PreloadManager

单例模式的 Facade 入口，所有对外 API 均通过 `PreloadManager.instance` 访问。

#### `configure(config)`

更新全局配置。如果在任务执行过程中调用，会同时重建引擎。

```dart
PreloadManager.instance.configure(PreloadConfig(
  maxConcurrentTasks: 6,
  defaultTimeout: const Duration(seconds: 45),
));
```

#### `register<T>(target, ...)`

注册一个预加载任务，返回 `PreloadManager` 实例本身，支持链式调用。自动区分 Provider 任务和方法任务：

- `target` 为 `ProviderListenable` → **Provider 任务**
- `target` 为 `Future<void> Function()` → **方法任务**

参数列表：

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | `String?` | 自动推断 | 任务 ID（必须唯一），用于依赖引用和日志标识 |
| `dependencies` | `List<String>` | `[]` | 依赖的其他任务 ID 列表 |
| `checkBeforeExecute` | `Future<bool> Function()?` | `null` | 执行前检查函数，返回 `true` 才能执行 |
| `checkRetryDelay` | `Duration?` | `300ms` | 检查失败后重试间隔 |
| `maxCheckRetries` | `int` | `10` | 检查最大重试次数 |
| `priority` | `int` | `1` | 同层级任务优先级（越大越先执行） |
| `required` | `bool` | `true` | 是否为必需任务 |
| `timeout` | `Duration?` | 全局配置 | 单任务超时时间 |

#### `registerBatch(tasks)`

批量注册任务，适合从配置文件或外部定义的任务列表导入。

```dart
final tasks = [
  PreloadTask(provider: providerA, id: 'a'),
  PreloadTask(provider: providerB, id: 'b', dependencies: ['a']),
];
PreloadManager.instance.registerBatch(tasks);
```

#### `execute({container})`

执行所有已注册的任务，返回 `Future<PreloadExecutionResult>`。

- 内部自动创建 `ProviderContainer` 用于读取 Provider
- 如果传入了外部 `container`，则复用该容器
- 已在执行中时抛出 `PreloadException`

#### `cancel()`

取消正在执行的预加载，所有未完成的任务将被标记为 `cancelled`。

#### `clear()`

清空所有已注册的任务。如果当前正在执行，先取消再清空。

#### `progress` (Stream)

实时进度流，类型为 `Stream<PreloadProgress>`。所有订阅者共享同一个流（broadcast stream）。

#### `state` (Getter)

获取当前管理器状态，`PreloadManagerState` 枚举值。

---

### 4.2 PreloadConfig

全局配置类，控制引擎的整体行为。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `maxConcurrentTasks` | `int` | `3` | 最大并发执行的任务数 |
| `defaultTimeout` | `Duration` | `30s` | 任务默认超时时间 |
| `maxRetries` | `int` | `2` | Provider 任务失败重试次数 |
| `retryBaseDelay` | `Duration` | `500ms` | 重试间隔基数（指数退避：`delay * 2^attempt`） |
| `enableLogging` | `bool` | `true` | 是否输出详细日志 |
| `onError` | `Function` | `null` | 全局错误回调 |
| `defaultCheckRetryDelay` | `Duration` | `300ms` | 任务级检查重试间隔默认值 |
| `defaultMaxCheckRetries` | `int` | `10` | 任务级检查最大重试次数默认值 |
| `globalCheck` | `Future<bool> Function()?` | `null` | **全局执行前检查**，每个任务执行前都会调用 |
| `globalCheckRetryDelay` | `Duration?` | `null` | 全局检查重试间隔（`null` 用默认值） |
| `globalCheckMaxRetries` | `int?` | `null` | 全局检查最大重试次数（`null` 用默认值） |

> **全局检查与任务级检查的区别**：全局检查作用于所有任务，任务级检查只作用于单个任务。两者可以叠加使用，全局检查先于任务级检查执行。

---

### 4.3 PreloadTask 与 TaskConfig

`PreloadTask` 是任务的通用模型，支持 Provider 和方法两种执行方式。

```dart
PreloadTask(
  provider: myProvider,          // ProviderListenable? — Provider 任务
  method: () async {},           // Future<void> Function()? — 方法任务
  id: 'unique-task-id',          // 唯一标识（必须）
  dependencies: ['dep-id-1'],    // 依赖列表
  checkBeforeExecute: () async => true,
  checkRetryDelay: Duration(milliseconds: 500),
  maxCheckRetries: 5,
  config: TaskConfig(
    priority: 2,                 // 优先级（越大越高）
    required: true,              // 是否必需
    timeout: Duration(seconds: 30),
    name: '显示名称',
  ),
)
```

`TaskConfig` 包含任务的执行策略配置：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `priority` | `int` | `1` | 优先级，影响同层级任务的调度顺序 |
| `required` | `bool` | `true` | 必需标记 |
| `timeout` | `Duration?` | `null` | 超时时间（`null` 使用全局配置） |
| `name` | `String?` | `null` | 显示名称 |

**`copyWith` 方法**：支持以不可变方式创建任务副本，常用于从模板生成变体任务。

---

### 4.4 PreloadProgress

通过 `PreloadManager.instance.progress` Stream 实时推送的进度对象。

| 字段 | 类型 | 说明 |
|------|------|------|
| `state` | `PreloadManagerState` | 当前整体状态 |
| `totalTasks` | `int` | 总任务数 |
| `completedTasks` | `int` | 已完成任务数 |
| `runningTasks` | `int` | 正在执行的任务数 |
| `failedTasks` | `int` | 失败的任务数 |
| `progress` | `double` | 完成百分比（0.0 - 1.0） |
| `progressPercentage` | `String` | 格式化的百分比字符串，如 `"45.5%"` |
| `failedTasksDetails` | `Map<String, Object>` | 失败任务的详细信息 |
| `startTime` | `DateTime?` | 开始时间 |
| `estimatedTimeRemaining` | `Duration?` | 预计剩余时间（基于当前进度估算） |

**便捷判断方法**：
- `isRunning` — 是否正在执行
- `isCompleted` — 是否已完成
- `isFailed` — 是否失败

---

### 4.5 PreloadExecutionResult

`execute()` 方法的返回值，描述整个预加载流程的执行结果。

| 字段 | 类型 | 说明 |
|------|------|------|
| `result` | `PreloadResult` | 执行结果枚举值 |
| `completedTasks` | `int` | 成功完成的任务数 |
| `failedTasks` | `int` | 失败的任务数 |
| `totalTasks` | `int` | 总任务数 |
| `failedTaskDetails` | `Map<String, Object>` | 失败任务的名称→错误信息映射 |
| `executionTime` | `Duration` | 总执行耗时 |
| `successRate` | `double` | 成功率（0.0 - 1.0） |
| `isCompleteSuccess` | `bool` | 是否完全成功 |
| `isPartialSuccess` | `bool` | 是否部分成功 |

---

### 4.6 状态枚举

#### PreloadManagerState（管理器状态）

| 枚举值 | 说明 |
|--------|------|
| `idle` | 空闲，未在执行 |
| `running` | 正在执行 |
| `completed` | 执行完成 |
| `failed` | 执行失败 |
| `cancelled` | 被取消 |

#### PreloadTaskState（单个任务状态）

| 枚举值 | 说明 |
|--------|------|
| `pending` | 等待执行 |
| `loading` | 正在执行 |
| `completed` | 已完成 |
| `failed` | 执行失败 |
| `cancelled` | 被取消 |

#### PreloadResult（执行结果）

| 枚举值 | 说明 |
|--------|------|
| `success` | 所有任务成功 |
| `partialSuccess` | 部分成功（存在非必需任务失败） |
| `failed` | 失败（有必需任务失败） |
| `cancelled` | 被取消 |

---

## 5. 进阶用法

### 5.1 条件注册

根据环境或设备条件决定注册哪些任务：

```dart
final manager = PreloadManager.instance;

// 基础数据（始终加载）
manager.register(userProvider, name: 'user');

// 仅在有网络时加载远程数据
final isOnline = await Connectivity().checkConnectivity() != ConnectivityResult.none;
if (isOnline) {
  manager.register(remoteConfigProvider, name: 'remote-config');
}

// 仅在大屏设备上加载复杂 UI 数据
if (MediaQuery.of(context).size.shortestSide > 600) {
  manager.register(detailedListProvider, name: 'detailed-list', required: false);
}

await manager.execute();
```

### 5.2 动态依赖

依赖关系不仅限于静态声明，可以在执行过程中根据前置任务的结果动态调整后续任务的依赖：

```dart
// 注册初始探测任务（总是执行）
PreloadManager.instance.register(
  () async {
    final features = await FeatureDetector.detect();
    return features;
  },
  name: 'feature-detect',
);

// 根据探测结果决定是否加载高级功能
final features = await FeatureDetector.detect();
if (features.supportsOfflineMaps) {
  PreloadManager.instance.register(
    offlineMapsProvider,
    name: 'offline-maps',
    dependencies: ['feature-detect'],
  );
}
```

### 5.3 带超时的渐进式加载

为不同类型的资源设置不同的超时时间：

```dart
PreloadManager.instance
    // 快速资源：短超时
    .register(localAssetsProvider, name: 'local-assets', timeout: const Duration(seconds: 5))
    // 网络资源：中等超时
    .register(remoteConfigProvider, name: 'remote-config', timeout: const Duration(seconds: 15))
    // 复杂计算：长超时
    .register(
      complexIndexProvider,
      name: 'complex-index',
      timeout: const Duration(seconds: 60),
    );
```

### 5.4 复用 ProviderContainer

如果应用需要在预加载后复用已有的 Provider 状态，可以传入已有的容器：

```dart
final container = ProviderContainer();

await PreloadManager.instance
    .register(userProvider, name: 'user')
    .register(configProvider, name: 'config')
    .execute(container: container);  // 传入外部容器

// 预加载后，container 中已包含加载后的数据
final user = container.read(userProvider);
final config = container.read(configProvider);

// 应用结束后手动销毁
container.dispose();
```

### 5.5 取消与重新执行

支持中途取消后重新注册和执行：

```dart
final manager = PreloadManager.instance;

// 开始预加载
final future = manager.execute();

// 在某个条件下取消（例如用户快速跳过引导页）
if (userSkippedOnboarding) {
  manager.cancel();
  // 或者清空所有任务重新开始
  manager.clear();
  await manager
      .register(simplifiedUserProvider, name: 'user')
      .execute();
}
```

### 5.6 自定义进度 UI

结合 Riverpod 构建进度展示界面：

```dart
class PreloadOverlay extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(preloadProgressProvider);

    return progressAsync.when(
      data: (progress) {
        if (!progress.isRunning) return const SizedBox.shrink();
        return Stack(
          children: [
            // 半透明背景
            Container(color: Colors.black54),
            // 进度卡片
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(value: progress.progress),
                  const SizedBox(height: 16),
                  Text(
                    '加载中... ${progress.progressPercentage}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (progress.estimatedTimeRemaining != null)
                    Text(
                      '预计还需 ${progress.estimatedTimeRemaining!.inSeconds}s',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// Riverpod Provider 包装进度流
final preloadProgressProvider = StreamProvider<PreloadProgress>((ref) {
  return PreloadManager.instance.progress;
});
```

---

## 6. 架构设计

### 6.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                      PreloadManager                      │
│                    (Facade 入口)                         │
│  ·register() ·configure() ·execute() ·cancel() ·progress │
└──────────┬──────────────────────────┬───────────────────┘
           │                          │
           │ 管理任务列表               │ 共享 tracker
           ▼                          ▼
┌──────────────────┐         ┌─────────────────┐
│   PreloadEngine  │────────▶│  PreloadTracker  │
│   (执行引擎)      │         │   (进度追踪)     │
│  ·依赖解析        │         │  ·状态变更       │
│  ·层级调度        │         │  ·去抖动推送     │
│  ·并发控制        │         │  ·进度计算       │
│  ·重试策略        │         └─────────────────┘
└────────┬─────────┘
         │
    ┌────┴──────────┐
    │               │
    ▼               ▼
PreloadSemaphore  DependencyGraph
 (并发控制)        (拓扑排序)
```

### 6.2 执行流程

```
execute() 启动
     │
     ▼
DependencyGraph.validate()     ──▶ 检测循环依赖
     │
     ▼
DependencyGraph.buildExecutionOrder()  ──▶ Kahn 拓扑排序，生成层级列表
     │
     ▼
PreloadTracker.start()         ──▶ 初始化所有任务上下文
     │
     ├─▶ [Level 0 任务] ──┐
     │   (并发执行，受 Semaphore 限制)
     │                    │
     │  ├─ Provider 任务 → container.read(provider)
     │  └─ 方法任务     → method()
     │
     ├─▶ [Level 1 任务] ──┐  （等待 Level 0 全部完成）
     │   (并发执行)
     │
     ├─▶ [Level 2 任务] ──┐  （等待 Level 1 全部完成）
     │   (并发执行)
     │
     ▼
必要检查：如果有必需任务失败 → cancel() 所有等待中的任务
     │
     ▼
PreloadTracker.complete()      ──▶ 构建 PreloadExecutionResult
     │
     ▼
返回执行结果
```

### 6.3 并发控制原理

`PreloadSemaphore` 基于 Dart 的 `Completer` 和 `Queue` 实现信号量模式：

```dart
// 获取信号量（阻塞直到有可用槽位）
await acquire();
// 执行任务
try {
  return await task();
} finally {
  release();  // 归还槽位，唤醒一个等待者
}
```

当 `maxConcurrentTasks = 3` 时，同一时刻最多有 3 个任务在执行，其余任务在队列中等待。

### 6.4 指数退避重试

任务失败后，重试间隔按指数增长：

```
attempt=0: 立即执行
attempt=1: 等待 500ms * 2^0 = 500ms
attempt=2: 等待 500ms * 2^1 = 1000ms
attempt=3: 等待 500ms * 2^2 = 2000ms
```

这避免了频繁重试对后端或设备的压力。

---

## 7. 异常处理

### 7.1 异常类型

| 异常类 | 说明 |
|--------|------|
| `PreloadException` | 基类，包含 `message` 和可选的 `cause` |
| `CircularDependencyException` | 检测到任务间存在循环依赖 |
| `PreloadTimeoutException` | 任务执行超时 |
| `PreloadTaskFailedException` | 单个任务执行失败 |
| `PreloadConfigException` | 配置参数错误 |

### 7.2 全局错误处理

通过 `PreloadConfig.onError` 集中处理所有错误：

```dart
PreloadManager.instance.configure(PreloadConfig(
  onError: (error, stackTrace) {
    // 发送到错误监控
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
    // 或者记录到本地日志
    debugPrint('预加载错误: $error');
  },
));
```

### 7.3 分级错误处理

通过 `PreloadExecutionResult` 获取详细的失败信息：

```dart
final result = await PreloadManager.instance.execute();

if (!result.isCompleteSuccess) {
  if (result.result == PreloadResult.failed) {
    // 必需任务失败，应用无法继续
    showErrorDialog('关键数据加载失败，请检查网络后重试');
  } else if (result.result == PreloadResult.partialSuccess) {
    // 部分可选任务失败，可以继续但功能受限
    for (final entry in result.failedTaskDetails.entries) {
      debugPrint('任务 ${entry.key} 失败: ${entry.value}');
    }
    showWarningSnackbar('部分功能加载失败，已跳过');
  }
}
```

---

## 8. 最佳实践

### 8.1 任务划分原则

- **按资源类型划分**：每个独立的资源（用户数据、配置、主题等）对应一个任务。
- **按依赖层级划分**：无依赖的资源在第一层，有依赖的按依赖深度分层。
- **避免过度拆分**：如果两个 Provider 总是一起加载且没有依赖关系，合并为一个任务可以减少调度开销。
- **避免过度聚合**：单个任务不应该包含太多逻辑，否则一旦失败粒度过粗，不利于排查。

### 8.2 优先级设置

- **UI 关键路径**：设置为 `priority: 10`（最高），确保首屏渲染所需的数据最先加载。
- **后台数据**：设置为 `priority: 1`（最低），允许被高优先级任务"插队"。
- **跨层级调度**：同层级内，优先级高的任务先获得执行机会（通过 `sort` 排序）。

```dart
// 首屏必需：最高优先级
.register(homeDataProvider, name: 'home-data', priority: 10)

// 次要功能：中等优先级
.register(analyticsProvider, name: 'analytics', priority: 5)

// 预加载优化：低优先级
.register(recommendationProvider, name: 'recommendation', priority: 1, required: false)
```

### 8.3 超时设置

- **本地同步资源**（SharedPreferences）：`5s`
- **本地异步资源**（SQLite 数据库）：`15s`
- **网络资源**（API 调用）：`30s`
- **大型数据处理**（索引构建、ML 模型加载）：`60s` 或更长

### 8.4 日志使用

在开发环境中启用详细日志，生产环境按需关闭：

```dart
PreloadManager.instance.configure(PreloadConfig(
  enableLogging: kDebugMode,  // 仅开发环境
));
```

### 8.5 避免的错误模式

**错误1：循环依赖**

```dart
// ❌ 错误：任务 A 依赖 B，任务 B 又依赖 A
.register(providerA, name: 'a', dependencies: ['b']);
.register(providerB, name: 'b', dependencies: ['a']);
// 抛出 CircularDependencyException
```

**错误2：在 Provider 中执行副作用**

```dart
// ❌ 错误：Provider 应该只描述状态，不应执行副作用
final badProvider = FutureProvider((ref) async {
  // 这些应该在方法任务中执行，而非 Provider
  await Database.init();
  await Analytics.init();
  return Data.load();
});

// ✅ 正确：Provider 只负责返回数据
final goodProvider = FutureProvider((ref) async {
  return Data.load();  // 数据已通过预加载就绪
});
```

**错误3：未检查重复注册**

同一任务 ID 被多次注册时，`_registeredTasks` 中会存在两个相同 ID 的任务。由于 `PreloadTask` 的 `==` 和 `hashCode` 基于 `id`，依赖解析可能产生意外行为。建议在应用启动时使用 `clear()` 确保干净状态：

```dart
@override
void initState() {
  super.initState();
  PreloadManager.instance.clear();  // 先清空
  _registerAndExecute();
}
```

---

## 9. 常见问题

### Q1: 任务执行顺序和注册顺序一致吗？

不完全一致。注册顺序不影响执行顺序——执行顺序由**依赖关系**和**优先级**决定。无依赖的任务按注册顺序进入 Level 0，同层级内的任务按**优先级降序**排列。

### Q2: Provider 任务和方法任务可以相互依赖吗？

可以。依赖通过字符串 ID 声明，不区分任务类型。例如方法任务可以依赖 Provider 任务，Provider 任务也可以依赖方法任务。

### Q3: `globalCheck` 和 `checkBeforeExecute` 可以同时使用吗？

可以。两者的执行顺序是：`globalCheck`（全局前置条件）→ `checkBeforeExecute`（任务级前置条件）→ 实际执行。`globalCheck` 适用于"所有任务共同的前置条件"（如 App 是否在前台），任务级检查适用于"单个任务的特定条件"（如数据库连接是否就绪）。

### Q4: 任务执行中调用 `cancel()` 会立即停止吗？

不会立即停止正在执行的任务（任务一旦开始运行就无法中断），但会：
1. 阻止新任务开始执行（通过 `_token.isCancelled` 检查）。
2. 将所有等待中的任务标记为 `cancelled`。
3. 释放信号量，允许后续操作重新开始。

### Q5: 如何调试预加载的执行过程？

启用详细日志后，所有操作都会输出到控制台：

```dart
PreloadManager.instance.configure(PreloadConfig(enableLogging: true));
// 日志前缀：[PRELOAD_MGR] 和 [PRELOAD_ENGINE]
```

关键日志标记：
- `[REGISTER]` — 任务注册
- `[EXECUTE]` — 执行开始/结束
- `[GLOBAL_CHECK]` — 全局检查状态
- `Provider任务 X 第 Y 次尝试失败` — Provider 重试
- `任务 X 检查未通过` — 检查重试

### Q6: 进度流在 UI 中为什么会抖动？

`PreloadTracker` 内部有 50ms 的去抖动机制（`debounceThreshold`），用于合并快速连续的进度更新，避免 UI 频繁重建。如果需要更平滑的进度展示，可以在 UI 层再做一次 `AnimatedBuilder` 插值。

### Q7: 多次调用 `execute()` 会发生什么？

第二次调用时，如果状态为 `running`，会抛出 `PreloadException('预加载已在进行中')`。如果需要重新执行，先调用 `cancel()` 或 `clear()`。

### Q8: 如何扩展新的任务类型？

模块设计为支持 Provider 和方法两种类型。如果需要支持新的任务类型（如基于 `Stream` 的任务），可以继承 `PreloadTask` 并扩展 `_execute` 逻辑：

```dart
// 扩展 PreloadEngine._executeTask 方法
if (task is StreamPreloadTask) {
  await _executeStreamTask(task, container);
}
```

---

## 参考

- 模块导出入口：`utils/preload/preload.dart`
- Facade 入口：`PreloadManager`（`preload_manager.dart`）
- 配置：`PreloadConfig`（`config/preload_config.dart`）
- 任务模型：`PreloadTask`、`TaskConfig`（`model/preload_task.dart`）
- 执行引擎：`PreloadEngine`（`engine/preload_engine.dart`）
- 依赖分析：`DependencyGraph`（`engine/dependency_graph.dart`）
- 进度追踪：`PreloadTracker`（`tracker/preload_tracker.dart`）
- 并发控制：`PreloadSemaphore`（`control/preload_semaphore.dart`）
- 状态定义：`PreloadManagerState`、`PreloadTaskState`、`PreloadResult`（`state/preload_state.dart`）
