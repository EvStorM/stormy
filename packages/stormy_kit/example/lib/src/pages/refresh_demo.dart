import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

class RefreshDemoPage extends StatefulWidget {
  const RefreshDemoPage({super.key});

  @override
  State<RefreshDemoPage> createState() => _RefreshDemoPageState();
}

class _RefreshDemoPageState extends State<RefreshDemoPage> {
  final List<String> _items = [];
  late EasyRefreshController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    _loadInitialData();
  }

  void _loadInitialData() {
    for (int i = 0; i < 15; i++) {
      _items.add('Item $i');
    }
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _items.clear();
      _loadInitialData();
    });
    _controller.finishRefresh();
    _controller.resetFooter();
  }

  Future<void> _onLoadMore() async {
    await Future.delayed(const Duration(seconds: 1));
    final count = _items.length;
    setState(() {
      for (int i = count; i < count + 10; i++) {
        _items.add('Item $i');
      }
    });
    _controller.finishLoad();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      appBar: AppBar(title: const Text('Refresh Demo')),
      easyRefreshConfig: EasyRefreshConfig(
        controller: _controller,
        header: buildDefaultHeader(),
        footer: buildDefaultFooter(),
        onRefresh: _onRefresh,
        onLoad: _onLoadMore,
      ),
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_items[index]),
            leading: const Icon(Icons.star),
          );
        },
      ),
    );
  }
}
