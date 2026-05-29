# Stormy Kit - 弹窗模块 (`StormyDialog`) 开发指南

`StormyDialog` 提供全局统一的弹窗、通知和加载状态展示。其最显著的核心优势是**“脱离 Context 生命周期绑定”**——您可以在任何没有 Widget 上下文的异步回调（例如 Dio 网络请求拦截器中检测到 401 时）中直接弹出对话框。

---

## 1. 极其关键的初始化挂载

在应用程序的入口处，您**必须**将全局的 `navigatorKey` 绑定给 `MaterialApp`（或 `GoRouter` 路由管理器）。这是无需 `BuildContext` 就能定位和在顶层绘制 UI 节点的秘密所在。

```dart
// 在 MaterialApp 挂载
MaterialApp(
  navigatorKey: StormyDialog.navigatorKey, // 极其重要！不绑定会导致运行时报错崩溃
  home: const HomePage(),
);
```

---

## 2. 弹窗 API 列表

### 2.1 黑条轻提示 (`showToast`)

支持多种提示状态。它优于系统自带的 `SnackBar`，因为它的高度会自动适配，并且不会阻断用户的页面点击操作，还能防止与系统软键盘重叠。

```dart
// 成功提示
StormyDialog.instance.showToast('保存成功', type: ToastType.success);

// 错误提示
StormyDialog.instance.showToast('加载失败，请重试', type: ToastType.error);

// 普通警告/通知提示
StormyDialog.instance.showToast('电量过低', type: ToastType.warning);
StormyDialog.instance.showToast('为您加载了 10 条新内容', type: ToastType.info);
```

### 2.2 确认警示框 (`showAlert`)

弹出一个包含单按钮的同步警示框，提示用户某项不可逆的事实或警告。

```dart
await StormyDialog.instance.showAlert(
  title: '升级提示',
  message: '由于您的账户已过期，该功能已被临时锁定。',
);
```

### 2.3 交互选择框 (`showConfirm`)

通过 `await` 语法同步阻断异步代码流，当用户做出选择后，返回一个布尔值结果。

```dart
bool? isConfirmed = await StormyDialog.instance.showConfirm(
  title: '注销账户',
  message: '您确定要注销此账户吗？注销后所有存储资产将永久丢失且不可找回。',
  isDestructive: true, // 极其重要：将确认按钮渲染为红色警告样式（满足 iOS 规范）
);

if (isConfirmed == true) {
  // 执行核心注销逻辑
}
```

### 2.4 全局 Loading HUD 蒙层

适合在发起网络请求或执行耗时计算时锁定用户屏幕，防止用户的并发误触。

```dart
try {
  // 1. 弹出遮罩
  StormyDialog.instance.showLoading(message: '正在上传视频...');

  // 2. 发起耗时操作
  await videoUploader.upload();

  StormyDialog.instance.showToast('上传完成！', type: ToastType.success);
} catch (e) {
  StormyDialog.instance.showToast('上传异常', type: ToastType.error);
} finally {
  // 3. 无论成功或失败，都必须移除遮罩
  StormyDialog.instance.hideLoading();
}
```

---

## 3. 安全开发守则

*   **加载遮罩泄露防御**：每次调用 `showLoading`，都应将其包裹在 `try-finally` 结构的 `finally` 块中调用 `hideLoading`。防止接口超时或报错时遮罩层卡死在屏幕最上层。
*   **不绕过机制**：不要在业务层直接调用 `flutter_smart_dialog` 或手写 Overlay，以便将来对弹窗样式进行集中式改版升级。
