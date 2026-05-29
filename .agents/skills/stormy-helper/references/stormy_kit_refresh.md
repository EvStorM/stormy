# Stormy Kit - 刷新模块 (`StormyRefresh`) 开发指南

`StormyRefresh` 深度集成了优秀的下拉刷新与上拉加载库 `easy_refresh`，并且已经将**全局品牌配色样式**与**国际化多语言文案**在最底层做好了静默绑定。业务侧无需再为每个列表单独配置配色或文字。

---

## 1. 全局配置

首先，必须在 `main.dart` 启动时调用 `setRefresh()` 方法：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await stormy().build();
  
  // 必须在 build 完成后初始化刷新组件全局主题
  await setRefresh();
  
  runApp(const MyApp());
}
```

---

## 2. 业务基本用法

一旦全局配置完毕，在任意业务列表页中使用 `EasyRefresh`，它将自动呈现品牌特有的绿色加载圆圈（或根据当前亮暗模式自适应的主题色），以及强关联多语言配置的翻译文字：

```dart
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

class UserListView extends StatelessWidget {
  const UserListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EasyRefresh(
        // 下拉刷新触发的回调
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 2));
          // 执行你的网络刷新操作
        },
        // 上拉加载触发的回调 (若不配置，则只支持下拉，底部不会有上拉布局)
        onLoad: () async {
          await Future.delayed(const Duration(seconds: 2));
          // 执行你的分页拉取操作
        },
        child: ListView.builder(
          itemCount: 20,
          itemBuilder: (context, index) {
            return ListTile(title: Text('用户条目 $index'));
          },
        ),
      ),
    );
  }
}
```

---

## 3. 自定义刷新控制（进阶）

如果某些特殊页面需要主动用代码触发列表的刷新动作，可以使用 `EasyRefreshController`：

```dart
final EasyRefreshController _controller = EasyRefreshController(
  controlFinishRefresh: true,
  controlFinishLoad: true,
);

// 1. 主动用代码让列表弹下拉动画并刷新
_controller.callRefresh();

// 2. 网络结束后，用代码关闭刷新状态
_controller.finishRefresh(IndicatorResult.success);
_controller.finishLoad(IndicatorResult.noMore); // 判定没有下一页数据了
```

---

## 4. 架构优势说明

*   **全免配置**：业务开发人员无需在 UI 中写任何诸如 `ClassicHeader` 或 `ClassicFooter` 的字样，组件会自动从 `stormy_kit` 底层读取 `StormyI18n` 并自动根据用户的 Locale 决定拉取英文 “Pull to refresh” 还是中文 “下拉刷新”。
*   **深色模式自适应**：当用户切换系统至 Dark Mode 时，刷新的加载器会自动将背景底色和文字转换为淡灰色与淡绿色，保持界面色彩对比度。
