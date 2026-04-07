import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      appBar: AppBar(
        title: const Text('StormyKit Example'),
        centerTitle: true,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildItem(context, '网络模块', '演示 GET/POST、并发挂起与拦截', '/network', Icons.cloud),
            _buildItem(context, '存储模块', '演示本地存取、安全加密与过期策略', '/storage', Icons.sd_storage),
            _buildItem(context, '主题模块', '演示深浅色与自定义变体', '/theme', Icons.color_lens),
            _buildItem(context, '对话框模块', '演示 Loading、Toast、Confirm 与弹窗', '/dialog', Icons.message),
            _buildItem(context, '组件模块', '演示内置封装的基础 UI 组件', '/widgets', Icons.widgets),
            _buildItem(context, '多语言模块', '演示语言切换与动态持久化', '/i18n', Icons.translate),
            _buildItem(context, '刷新模块', '演示下拉刷新与分页加载', '/refresh', Icons.refresh),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, String title, String subtitle, String route, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: theme.primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push(route);
        },
      ),
    );
  }
}
