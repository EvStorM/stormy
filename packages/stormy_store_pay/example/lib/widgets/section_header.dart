import 'package:flutter/material.dart';

/// 分类标题
class SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const SectionHeader({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (title) {
      '消耗型' => Icons.local_fire_department,
      '非消耗型' => Icons.diamond_outlined,
      '非续期订阅' => Icons.timer_outlined,
      '自动续期订阅' => Icons.autorenew,
      _ => Icons.category,
    };
    final color = switch (title) {
      '消耗型' => Colors.orange,
      '非消耗型' => Colors.teal,
      '非续期订阅' => Colors.purple,
      '自动续期订阅' => Colors.blue,
      _ => cs.primary,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}
