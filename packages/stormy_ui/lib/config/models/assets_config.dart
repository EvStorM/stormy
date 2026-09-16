/// Dialog Config - 弹窗配置
/// 用于配置对话框、Toast、Loading 等弹窗样式
class StormyAssetsConfig {
  /// 取消按钮文字
  final String checkIcon;
  final String unCheckIcon;
  final String backIcon;

  const StormyAssetsConfig({
    this.checkIcon = '取消',
    this.unCheckIcon = '取消',
    this.backIcon = '取消',
  });

  /// 创建默认配置
  factory StormyAssetsConfig.defaultConfig() {
    return const StormyAssetsConfig(
      checkIcon: '取消',
      unCheckIcon: '取消',
      backIcon: '取消',
    );
  }

  /// 复制并修改配置
  StormyAssetsConfig copyWith({
    String? checkIcon,
    String? unCheckIcon,
    String? backIcon,
  }) {
    return StormyAssetsConfig(
      checkIcon: checkIcon ?? this.checkIcon,
      unCheckIcon: unCheckIcon ?? this.unCheckIcon,
      backIcon: backIcon ?? this.backIcon,
    );
  }
}
