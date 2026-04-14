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
  List<StoreProductInfo> _products = [];

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

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _initStorePay() async {
    try {
      _log('初始化支付 SDK...');
      await StorePayManager.instance.initialize(
        config: const StorePayConfig(
          autoCompletePurchases: true,
          isForTest: true,
          consumableProductIds: {
            'stormy.store.coins.hundred',
            'stormy.store.energy.ten',
          },
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
      await StorePayManager.instance.queryProducts(
        allProductIds,
        autoRestorePurchases: true,
      );
    } catch (e) {
      _log('查询异常: $e');
    }
  }

  Future<void> _purchaseProduct(StoreProductInfo product) async {
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

  /// 按产品类型分组
  Map<String, List<StoreProductInfo>> get _groupedProducts {
    final map = <String, List<StoreProductInfo>>{
      '直充消耗品': [],
      '非消耗品 (终身)': [],
      '订阅服务': [],
      '未知': [],
    };

    for (final p in _products) {
      switch (p.type) {
        case StoreProductType.consumable:
          map['直充消耗品']!.add(p);
        case StoreProductType.nonConsumable:
          map['非消耗品 (终身)']!.add(p);
        case StoreProductType.subscription:
          map['订阅服务']!.add(p);
        case StoreProductType.unknown:
          map['未知']!.add(p);
      }
    }

    // 移除空分类
    map.removeWhere((_, v) => v.isEmpty);
    return map;
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Pay 2.0 测试'),
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
                  flex: 2,
                  child: _products.isEmpty
                      ? const Center(
                          child: Text(
                            '尚未加载产品',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _groupedProducts.length,
                          itemBuilder: (context, index) {
                            final title = _groupedProducts.keys.elementAt(index);
                            final items = _groupedProducts[title]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  title: title,
                                  count: items.length,
                                ),
                                ...items.map(
                                  (p) => ProductCard(
                                    product: p,
                                    onPurchase: () => _purchaseProduct(p),
                                    onViewDetail: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor:
                                            Colors.transparent,
                                        builder:
                                            (ctx) => ProductDetailSheet(
                                              product: p,
                                              onPurchase:
                                                  (product, offer) {
                                                Navigator.pop(ctx);
                                                StorePayManager.instance.purchaseProduct(product, offer: offer);
                                              },
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),

                const Divider(height: 1),
                LogPanel(logs: _logs, onClear: _clearLogs),
              ],
            ),
    );
  }
}
