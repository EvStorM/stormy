import 'package:flutter/material.dart';

/// 日志区域头部
class LogHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const LogHeader({super.key, required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 14),
          const SizedBox(width: 4),
          Text(
            '日志 ($count)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: Text(
              '清空',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 日志面板区域
class LogPanel extends StatelessWidget {
  final List<String> logs;
  final VoidCallback onClear;

  const LogPanel({super.key, required this.logs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Column(
        children: [
          LogHeader(
            count: logs.length,
            onClear: onClear,
          ),
          Expanded(
            child: Container(
              color: Colors.black87,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
