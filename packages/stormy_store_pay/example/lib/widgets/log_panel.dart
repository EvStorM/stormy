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
