/// 支付宝 SDK 配置
class AlipayConfig {
  /// 支付宝授权 AppId
  final String authAppId;

  /// Universal Link
  final String universalLink;

  AlipayConfig({required this.authAppId, required this.universalLink});

  /// 默认配置
  factory AlipayConfig.defaultConfig() {
    return AlipayConfig(
      authAppId: '60000157',
      universalLink: 'https://qpweb.bjbhd.xyz/link',
    );
  }
}
