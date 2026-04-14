import 'package:flutter/material.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

/// 产品卡片
class ProductCard extends StatelessWidget {
  final ProductDetails product;
  final AppleProductInfo? appleInfo;
  final VoidCallback onPurchase;
  final VoidCallback onViewDetail;

  const ProductCard({
    super.key,
    required this.product,
    this.appleInfo,
    required this.onPurchase,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subInfo = appleInfo?.subscriptionInfo;
    final hasOffers = (subInfo?.promotionalOffers.isNotEmpty ?? false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onViewDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasOffers) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '有优惠',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.id,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (subInfo != null) ...[
                      const SizedBox(height: 4),
                      _SubscriptionBadge(info: subInfo),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 购买按钮
              Column(
                children: [
                  FilledButton(
                    onPressed: onPurchase,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(product.price),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== 订阅周期标签 ==========

class _SubscriptionBadge extends StatelessWidget {
  final AppleSubscriptionInfo info;

  const _SubscriptionBadge({required this.info});

  String _periodText(AppleSubscriptionPeriodInfo p) {
    final unitStr = switch (p.unit) {
      AppleSubscriptionPeriodUnit.day => '天',
      AppleSubscriptionPeriodUnit.week => '周',
      AppleSubscriptionPeriodUnit.month => '月',
      AppleSubscriptionPeriodUnit.year => '年',
      _ => '?',
    };
    return '${p.value}$unitStr';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '周期: ${_periodText(info.subscriptionPeriod)}',
            style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
          ),
        ),
        if (info.promotionalOffers.isNotEmpty) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${info.promotionalOffers.length} 个优惠',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
            ),
          ),
        ],
      ],
    );
  }
}
