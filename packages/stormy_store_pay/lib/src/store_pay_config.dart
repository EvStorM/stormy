/// 内购管理器配置
///
/// 用于在初始化时配置内购管理器的可选行为
class StorePayConfig {
  /// 是否在购买完成后自动完成（complete）购买
  ///
  /// 默认为 true。设置为 false 时需要业务层手动调用 completePurchase
  final bool autoCompletePurchases;

  /// 是否使用沙盒/开发环境（仅 Apple 支持）
  ///
  /// 默认为 false（生产环境）
  final bool isForTest;

  /// 自定义应用用户标识（可选）
  ///
  /// 用于在购买时关联用户身份，便于恢复购买时识别用户
  final String? applicationUserName;

  /// 消耗型产品ID集合
  ///
  /// 用于精确区分消耗型产品，避免依赖不可靠的字符串推断。
  /// 在 Google Play 平台上尤其重要，因为 Google Play 无法从产品信息自动推断类型。
  final Set<String> consumableProductIds;

  const StorePayConfig({
    this.autoCompletePurchases = true,
    this.isForTest = false,
    this.applicationUserName,
    this.consumableProductIds = const {},
  });

  /// 默认配置
  static const StorePayConfig defaultConfig = StorePayConfig();
}
