/// 微信 SDK 配置
class WechatConfig {
  /// 微信 AppId
  final String appId;

  /// Universal Link
  final String universalLink;

  /// 小程序用户名
  final String miniProgramUsername;

  WechatConfig({
    required this.appId,
    required this.universalLink,
    required this.miniProgramUsername,
  });

  /// 默认配置
  factory WechatConfig.defaultConfig() {
    return WechatConfig(
      appId: 'wx86636fd836482486',
      universalLink: 'https://your.univerallink.com/link/',
      miniProgramUsername: 'gh_d43f693ca31f',
    );
  }
}
