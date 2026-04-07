import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

class NetworkDemoPage extends StatefulWidget {
  const NetworkDemoPage({super.key});

  @override
  State<NetworkDemoPage> createState() => _NetworkDemoPageState();
}

class _NetworkDemoPageState extends State<NetworkDemoPage> {
  String _result = 'Waiting for action...';
  bool _isLoading = false;
  bool _isChecked = false;

  void _appendResult(String text) {
    if (!mounted) return;
    setState(() {
      _result += '\n$text';
      _isLoading = false;
    });
  }

  void _clearResult() {
    setState(() {
      _result = '';
      _isLoading = true;
    });
  }

  Future<void> _fetchData() async {
    _clearResult();
    try {
      // 演示：使用配置中生成的全局 Network 客户端发起请求
      // 注意：由于 NetworkConfig.defaultRequireToken 默认为 true
      // 如果未调用 completeGlobalToken，请求默认会被 AuthInterceptor 挂起拦截
      _appendResult('Sending GET request to /dict/type...');

      final client = StormyConfigAccessor.networkClient;
      if (client == null) {
        _appendResult('Error: Network client not initialized.');
        return;
      }

      // 演示：强制覆盖 Opt-out，标记此请求不需要 Token
      // 因此该请求会立即发送，不会被 AuthInterceptor 挂起
      final res = await client.get<List<dynamic>>(
        '/style-background-configs',
        requireToken: false,
        parser: const DirectParser<List<dynamic>>(),
      );
      final resStr = res.toString();
      final displayStr =
          resStr.length > 100 ? '${resStr.substring(0, 100)}...' : resStr;
      _appendResult('Response:\n$displayStr');
    } catch (e, st) {
      StormyLog.e(e.toString(), stackTrace: st);
      _appendResult('Error: ${e.toString()}');
    }
  }

  Future<void> _testTokenSuspend() async {
    _clearResult();

    final client = StormyConfigAccessor.networkClient;
    if (client == null) return;

    _appendResult('Sending request requiring Token... (Will suspend)');

    // 不 await，让它挂起
    client
        .get('/dict/type', requireToken: true, requireHeader: false)
        .then((res) {
      final resStr = res.toString();
      final displayStr =
          resStr.length > 100 ? '${resStr.substring(0, 100)}...' : resStr;
      _appendResult(
          'Suspended request completed successfully!\nResponse:\n$displayStr');
    }).catchError((e) {
      _appendResult('Suspended request failed: $e');
    });

    _appendResult('Waiting 3 seconds before injecting token...');

    await Future.delayed(const Duration(seconds: 3));
    _appendResult('Injecting Token Now!');

    // 注入 Token 释放挂起
    client.completeGlobalHeader({});
  }

  void _testCancellation() {
    _clearResult();

    final client = StormyConfigAccessor.networkClient;
    if (client == null) return;

    _appendResult('Sending request with tag [demo_tag]...');

    client
        .get('/dict/type',
            cancelTag: 'demo_tag', requireToken: false, requireHeader: false)
        .then((res) {
      _appendResult('Request success!');
    }).catchError((e) {
      _appendResult('Request caught: $e');
    });

    // 立即取消
    Future.delayed(const Duration(milliseconds: 100), () {
      _appendResult('Cancelling requests with tag [demo_tag]...');
      client.cancelByTag('demo_tag');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Demo')),
      body: Column(
        children: [
          Container(
            width: 1.sw,
            padding: context.theme.mainPadding,
            child: AgreementWidget(
              isChecked: _isChecked,
              onChanged: (value) {
                setState(() {
                  _isChecked = value;
                });
              },
              iconSize: 14.0,
              spacing: 2.0,
              mainAxisAlignment: MainAxisAlignment.center, // 整体居中
              textAlign: TextAlign.start, // 多行文本居中
              textStyle: TextStyle(fontSize: 13.sp, color: Colors.grey),
              protocolStyle:
                  TextStyle(fontSize: 13.sp, color: context.theme.primary),
              segments: const [
                TextSegment('已阅读并接受'),
                ProtocolSegment(
                    AgreeItemModel(label: '《用户协议》', agreeUrl: '...')),
                TextSegment('以及'),
                ProtocolSegment(
                    AgreeItemModel(label: '《隐私政策》', agreeUrl: '...')),
                TextSegment('已阅读并接受已阅读并接受'),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: const TextStyle(
                      color: Colors.greenAccent, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _fetchData,
                  child: const Text('GET (No Token)'),
                ),
                ElevatedButton(
                  onPressed: _testTokenSuspend,
                  child: const Text('Test Token Suspend'),
                ),
                ElevatedButton(
                  onPressed: _testCancellation,
                  child: const Text('Test cancelByTag'),
                ),
                ElevatedButton(
                  onPressed: () {
                    StormyConfigAccessor.networkClient?.cancelAll();
                    _appendResult('cancelAll() executed.');
                  },
                  child: const Text('Cancel All'),
                ),
                ElevatedButton(
                  onPressed: () {
                    StormyConfigAccessor.networkClient?.resetGlobalAuthConfig();
                    _appendResult('Auth config reset.');
                  },
                  child: const Text('Reset Auth'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
