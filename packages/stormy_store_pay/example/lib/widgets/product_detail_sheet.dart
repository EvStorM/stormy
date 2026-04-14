import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

/// 产品详情弹窗
class ProductDetailSheet extends StatelessWidget {
  final ProductDetails product;
  final AppleProductInfo? appleInfo;
  final VoidCallback onPurchase;

  const ProductDetailSheet({
    super.key,
    required this.product,
    this.appleInfo,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subInfo = appleInfo?.subscriptionInfo;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // 拖拽指示器
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Text(
                product.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.description,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),

              const SizedBox(height: 16),

              // 基础信息
              _DetailSection(
                title: '基础信息',
                children: [
                  _InfoRow('产品 ID', product.id),
                  _InfoRow('价格', '${product.price} (${product.rawPrice})'),
                  _InfoRow(
                    '货币',
                    '${product.currencySymbol} ${product.currencyCode}',
                  ),
                  if (appleInfo != null) ...[
                    _InfoRow('产品类型', _productTypeName(appleInfo!.productType)),
                  ],
                ],
              ),

              // 订阅信息
              if (subInfo != null) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: '订阅信息',
                  children: [
                    _InfoRow('订阅周期', _periodText(subInfo.subscriptionPeriod)),
                    _InfoRow('订阅组 ID', subInfo.subscriptionGroupId),
                  ],
                ),
              ],

              // 优惠列表
              if (subInfo != null && subInfo.promotionalOffers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: '优惠方案 (${subInfo.promotionalOffers.length})',
                  children: [
                    for (final offer in subInfo.promotionalOffers)
                      _OfferRow(offer: offer),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // 购买按钮
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPurchase();
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('购买 ${product.price}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 使用优惠购买
              if (subInfo != null && subInfo.promotionalOffers.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _purchaseWithOffer(context, product);
                  },
                  icon: const Icon(Icons.local_offer_outlined),
                  label: const Text('使用优惠购买'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _purchaseWithOffer(
    BuildContext context,
    ProductDetails product,
  ) async {
    if (!Platform.isIOS) return;
    final ext = StorePayManager.instance.appleExtension;
    if (ext == null) return;

    final offers = await ext.getSubscriptionOffers(product.id);
    if (offers.isEmpty) return;

    // 直接使用第一个优惠
    await ext.purchaseWithOffer(product, offers.first);
  }

  String _productTypeName(AppleProductType type) {
    return switch (type) {
      AppleProductType.consumable => '消耗型 (Consumable)',
      AppleProductType.nonConsumable => '非消耗型 (Non-Consumable)',
      AppleProductType.nonRenewable => '非续期订阅 (Non-Renewing)',
      AppleProductType.autoRenewable => '自动续期订阅 (Auto-Renewable)',
      AppleProductType.unknown => '未知',
    };
  }

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
}

// ========== 详情区块 ==========

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

// ========== 信息行 ==========

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

// ========== 优惠行 ==========

class _OfferRow extends StatelessWidget {
  final AppleSubscriptionOfferInfo offer;

  const _OfferRow({required this.offer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final periodUnit = switch (offer.period.unit) {
      AppleSubscriptionPeriodUnit.day => '天',
      AppleSubscriptionPeriodUnit.week => '周',
      AppleSubscriptionPeriodUnit.month => '月',
      AppleSubscriptionPeriodUnit.year => '年',
      _ => '?',
    };
    final paymentStr = switch (offer.paymentMode) {
      AppleSubscriptionOfferPaymentMode.freeTrial => '免费试用',
      AppleSubscriptionOfferPaymentMode.payAsYouGo => '按期付费',
      AppleSubscriptionOfferPaymentMode.payUpFront => '预付',
      _ => '未知',
    };
    final offerTypeStr = switch (offer.type) {
      AppleSubscriptionOfferType.introductory => '入门优惠',
      AppleSubscriptionOfferType.promotional => '促销优惠',
      AppleSubscriptionOfferType.winBack => '回归优惠',
      _ => '未知',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  offerTypeStr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  paymentStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                offer.price == 0 ? '免费' : '¥${offer.price}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: offer.price == 0 ? Colors.green : cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${offer.id ?? "无"}  ·  周期: ${offer.period.value}$periodUnit × ${offer.periodCount}次',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
