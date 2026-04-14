
import 'package:flutter/material.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

/// 产品详情弹窗
class ProductDetailSheet extends StatelessWidget {
  final StoreProductInfo product;
  final void Function(StoreProductInfo product, StoreOfferInfo? offer) onPurchase;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subInfo = product.subscriptionInfo;
    final hasOffers = product.offers.isNotEmpty;
    final pInfo = product.priceInfo;

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
                    color: cs.onSurfaceVariant.withAlpha(77),
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
                  _InfoRow('类型', _productTypeName(product.type)),
                  _InfoRow('价格', pInfo.formattedPrice),
                  _InfoRow('本币标识', '${pInfo.currencySymbol} / ${pInfo.currencyCode}'),
                  if (pInfo.pricePerMonth != null) ...[
                     _InfoRow('约合月度', '${pInfo.currencySymbol}${pInfo.pricePerMonth!.toStringAsFixed(2)}/月'),
                  ]
                ],
              ),

              // 订阅信息
              if (subInfo != null) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: '订阅信息',
                  children: [
                    _InfoRow('订阅周期', _periodText(subInfo.period)),
                    _InfoRow('订阅组 ID', subInfo.groupId),
                    if (subInfo.googleBasePlanId != null)
                      _InfoRow('Google BasePlan ID', subInfo.googleBasePlanId!),
                  ],
                ),
              ],

              // 高级价格信息
              const SizedBox(height: 12),
              _DetailSection(
                title: '高级价格推导',
                children: [
                  _InfoRow('当前价格', pInfo.currentPrice.toString()),
                  _InfoRow('符号位置', pInfo.symbolBeforePrice ? '前置 (Prefix)' : '后置 (Suffix)'),
                  if (pInfo.pricePerDay != null) _InfoRow('日均价格', '${pInfo.currencySymbol}${pInfo.pricePerDay!.toStringAsFixed(3)}'),
                  if (pInfo.pricePerWeek != null) _InfoRow('周均价格', '${pInfo.currencySymbol}${pInfo.pricePerWeek!.toStringAsFixed(2)}'),
                  if (pInfo.pricePerMonth != null) _InfoRow('月均价格', '${pInfo.currencySymbol}${pInfo.pricePerMonth!.toStringAsFixed(2)}'),
                  if (pInfo.pricePerYear != null) _InfoRow('年均价格', '${pInfo.currencySymbol}${pInfo.pricePerYear!.toStringAsFixed(2)}'),
                ],
              ),

              // 优惠列表
              if (hasOffers) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: '优惠方案 (${product.offers.length})',
                  children: [
                    for (final offer in product.offers)
                      _OfferRow(offer: offer),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // 购买按钮
              FilledButton.icon(
                onPressed: product.isPurchased ? null : () => onPurchase(product, null),
                icon: Icon(product.isPurchased ? Icons.check_circle : Icons.shopping_cart_outlined),
                label: Text(product.isPurchased ? '已购买此项目' : '购买 ${product.priceInfo.formattedPrice}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 使用优惠购买
              if (hasOffers && !product.isPurchased) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    // 对于 Android，如果有一个主要 Offer，可以直接用来买
                    // iOS 则可以由用户选择对应的促销。此处默认获取最新一个有效的用于购买。
                    final firstUsableOffer = product.offers.first;
                    onPurchase(product, firstUsableOffer);
                  },
                  icon: const Icon(Icons.local_offer_outlined),
                  label: Text('使用第一个优惠购买 (${product.offers.first.priceInfo.formattedPrice})'),
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

  String _productTypeName(StoreProductType type) {
    return switch (type) {
      StoreProductType.consumable => '直冲消耗品',
      StoreProductType.nonConsumable => '非消耗品/终身',
      StoreProductType.subscription => '订阅/通行证',
      StoreProductType.unknown => '未知',
    };
  }

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
  final StoreOfferInfo offer;

  const _OfferRow({required this.offer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final periodUnit = switch (offer.period.unit) {
      StorePeriodUnit.day => '天',
      StorePeriodUnit.week => '周',
      StorePeriodUnit.month => '月',
      StorePeriodUnit.year => '年',
      _ => '?',
    };
    final paymentStr = switch (offer.paymentMode) {
      StorePaymentMode.freeTrial => '免费试用',
      StorePaymentMode.payAsYouGo => '按期付费',
      StorePaymentMode.payUpFront => '预付',
      _ => '未知',
    };
    final offerTypeStr = switch (offer.type) {
      StoreOfferType.introductory => '入门优惠',
      StoreOfferType.promotional => '促销优惠',
      StoreOfferType.freeTrial => '免费试用',
      _ => '未知',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withAlpha(77)),
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
                offer.priceInfo.currentPrice == 0 ? '免费' : offer.priceInfo.formattedPrice,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: offer.priceInfo.currentPrice == 0 ? Colors.green : cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${offer.id}  ·  周期: ${offer.period.value}$periodUnit × ${offer.paymentCount}次',
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }
}
