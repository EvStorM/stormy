import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stormy_store_pay/stormy_store_pay.dart';

import 'main.dart';
import 'widgets/log_panel.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_sheet.dart';
import 'widgets/section_header.dart';

class StorePayExamplePage extends StatefulWidget {
  const StorePayExamplePage({super.key});

  @override
  State<StorePayExamplePage> createState() => _StorePayExamplePageState();
}

class _StorePayExamplePageState extends State<StorePayExamplePage> {
  final List<String> _logs = [];
  bool _isInitializing = true;
  List<ProductDetails> _products = [];
  List<AppleProductInfo> _appleInfos = [];

  @override
  void initState() {
    super.initState();
    _initStorePay();
  }

  void _log(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, '$ts  $message');
    });
    debugPrint(message);
  }

  Future<void> _initStorePay() async {
    try {
      _log('初始化支付 SDK...');
      await StorePayManager.instance.initialize(
        config: const StorePayConfig(
          autoCompletePurchases: true,
          isForTest: true,
        ),
        verifier: (details) async {
          _log('验证购买凭证: ${details.productID}');
          await Future.delayed(const Duration(seconds: 1));
          return true;
        },
      );

      StorePayManager.instance.setCallbacks(
        onPurchaseSuccess: (event) {
          _log('购买成功: ${event.productId}, 恢复: ${event.isRestored}');
        },
        onPurchaseError: (error) {
          _log('购买失败: ${error.message}');
        },
        onProductsLoaded: (products) {
          _log('加载产品: ${products.length} 个');
          setState(() {
            _products = products;
          });
          _loadAppleInfos();
        },
        onPurchaseRestored: (event) {
          _log('恢复购买: ${event.productId}');
        },
      );

      setState(() => _isInitializing = false);
      _log('初始化完成');
      _queryProducts();
    } catch (e) {
      _log('初始化失败: $e');
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _queryProducts() async {
    _log('查询全部 ${allProductIds.length} 个产品...');
    try {
      await StorePayManager.instance.queryProducts(allProductIds);
    } catch (e) {
      _log('查询异常: $e');
    }
  }

  Future<void> _loadAppleInfos() async {
    if (!Platform.isIOS) return;
    final ext = StorePayManager.instance.appleExtension;
    if (ext == null) return;

    try {
      final infos = await ext.queryAppleProductInfos(allProductIds);
      setState(() => _appleInfos = infos);
      _log('Apple 详情: ${infos.length} 个');
    } catch (e) {
      _log('Apple 详情加载失败: $e');
    }
  }

  AppleProductInfo? _findAppleInfo(String productId) {
    return _appleInfos.cast<AppleProductInfo?>().firstWhere(
      (i) => i!.productId == productId,
      orElse: () => null,
    );
  }

  Future<void> _purchaseProduct(ProductDetails product) async {
    _log('尝试购买: ${product.id}');
    try {
      await StorePayManager.instance.purchaseProduct(product);
    } catch (e) {
      _log('购买异常: $e');
    }
  }

  Future<void> _restorePurchases() async {
    _log('请求恢复购买...');
    try {
      await StorePayManager.instance.restorePurchases();
    } catch (e) {
      _log('恢复购买异常: $e');
    }
  }

  Future<void> _presentCodeRedemption() async {
    if (!Platform.isIOS) return;
    final ext = StorePayManager.instance.appleExtension;
    if (ext == null) return;
    _log('打开促销代码兑换...');
    await ext.presentCodeRedemptionSheet();
  }

  // ========== 分类逻辑 ==========

  /// 按 Apple 产品类型分组
  Map<String, List<ProductDetails>> get _groupedProducts {
    final map = <String, List<ProductDetails>>{
      '消耗型': [],
      '非消耗型': [],
      '非续期订阅': [],
      '自动续期订阅': [],
      '未知': [],
    };

    for (final p in _products) {
      final info = _findAppleInfo(p.id);
      final type = info?.productType;
      switch (type) {
        case AppleProductType.consumable:
          map['消耗型']!.add(p);
        case AppleProductType.nonConsumable:
          map['非消耗型']!.add(p);
        case AppleProductType.nonRenewable:
          map['非续期订阅']!.add(p);
        case AppleProductType.autoRenewable:
          map['自动续期订阅']!.add(p);
        default:
          // 无 Apple 信息时按 ID 猜测
          if (p.id.contains('consumable') && !p.id.contains('non_consumable')) {
            map['消耗型']!.add(p);
          } else if (p.id.contains('non_consumable')) {
            map['非消耗型']!.add(p);
          } else if (p.id.contains('non_renewing')) {
            map['非续期订阅']!.add(p);
          } else if (p.id.contains('sub_')) {
            map['自动续期订阅']!.add(p);
          } else {
            map['未知']!.add(p);
          }
      }
    }

    // 移除空分类
    map.removeWhere((_, v) => v.isEmpty);
    return map;
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Pay SDK 测试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: _isInitializing ? null : _presentCodeRedemption,
            tooltip: '兑换促销码',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isInitializing ? null : _queryProducts,
            tooltip: '重新加载',
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 操作栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _restorePurchases,
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('恢复购买'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _queryProducts,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search, size: 18),
                              const SizedBox(width: 6),
                              Text('查询 (${_products.length})'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // 产品列表
                Expanded(
                  flex: 3,
                  child: _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '暂无商品',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          children: [
                            for (final entry in _groupedProducts.entries) ...[
                              SectionHeader(
                                title: entry.key,
                                count: entry.value.length,
                              ),
                              ...entry.value.map(
                                (p) => ProductCard(
                                  product: p,
                                  appleInfo: _findAppleInfo(p.id),
                                  onPurchase: () => _purchaseProduct(p),
                                  onViewDetail: () => _showProductDetail(p),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),

                // 日志区域
                const Divider(height: 1),
                LogHeader(
                  count: _logs.length,
                  onClear: () {
                    setState(() => _logs.clear());
                  },
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: cs.surfaceContainerLowest,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText(
                            _logs[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              height: 1.4,
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

  void _showProductDetail(ProductDetails product) {
    final appleInfo = _findAppleInfo(product.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductDetailSheet(
        product: product,
        appleInfo: appleInfo,
        onPurchase: () => _purchaseProduct(product),
      ),
    );
  }
}
