import 'package:flutter/material.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

/// 产品卡片
class ProductCard extends StatelessWidget {
  final StoreProductInfo product;
  final VoidCallback onPurchase;
  final VoidCallback onViewDetail;

  const ProductCard({
    super.key,
    required this.product,
    required this.onPurchase,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subInfo = product.subscriptionInfo;
    final hasOffers = product.offers.isNotEmpty;
    final isConsumable = product.type == StoreProductType.consumable;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withAlpha(128)),
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
                        if (product.isPurchased) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '已拥有',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ] else if (hasOffers) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withAlpha(38),
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
                        if (isConsumable) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '直充', // 消耗品
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade800,
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
                        color: cs.onSurfaceVariant.withAlpha(153),
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (subInfo != null) ...[
                      const SizedBox(height: 4),
                      _SubscriptionBadge(
                        info: subInfo,
                        offersText: hasOffers
                            ? '${product.offers.length} 个优惠'
                            : null,
                      ),
                      if (subInfo.googleBasePlanId != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'BasePlan: ${subInfo.googleBasePlanId}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.indigo.shade400,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 购买按钮
              Column(
                children: [
                  FilledButton(
                    onPressed: product.isPurchased ? null : onPurchase,
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
                    child: Text(
                      product.isPurchased
                          ? '已拥有'
                          : product.priceInfo.formattedPrice,
                    ),
                  ),
                  if (!product.isPurchased &&
                      product.priceInfo.pricePerMonth != null &&
                      product.priceInfo.pricePerMonth! <
                          product.priceInfo.currentPrice) ...[
                    const SizedBox(height: 2),
                    Text(
                      '约 ${product.priceInfo.currencySymbol}${product.priceInfo.pricePerMonth!.toStringAsFixed(2)}/月',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant.withAlpha(153),
                      ),
                    ),
                  ],
                  if (!product.isPurchased) ...[
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: cs.onSurfaceVariant.withAlpha(102),
                    ),
                  ],
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
  final StoreSubscriptionInfo info;
  final String? offersText;

  const _SubscriptionBadge({required this.info, this.offersText});

  String _periodText(StorePeriod p) {
    final unitStr = switch (p.unit) {
      StorePeriodUnit.day => '天',
      StorePeriodUnit.week => '周',
      StorePeriodUnit.month => '月',
      StorePeriodUnit.year => '年',
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
            '周期: ${_periodText(info.period)}',
            style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer),
          ),
        ),
        if (offersText != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              offersText!,
              style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
            ),
          ),
        ],
      ],
    );
  }
}
