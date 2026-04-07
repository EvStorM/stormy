import 'dart:async';

import 'package:fluwx/fluwx.dart';
import 'package:stormy_kit/stormy_kit.dart';
import 'package:tobias/tobias.dart';
import 'src/wechat/wechat_sdk.dart';
import 'src/wechat/wechat_config.dart';
import 'src/alipay/alipay_sdk.dart';
import 'src/alipay/alipay_config.dart';
import 'src/models/payment_event.dart';
import 'src/models/share_event.dart';
import 'src/models/auth_event.dart';

/// 支付类型枚举
enum SDKPaymentType {
  /// 微信支付
  weChat,

  /// 支付宝支付
  alipay,
}

/// 分享平台枚举
enum SharePlatform {
  /// 微信
  weChat,

  /// QQ
  qq,
}

/// 支付结果
class PayResult {
  /// 支付类型
  final SDKPaymentType type;

  /// 是否成功
  final bool isSuccess;

  /// 是否是签约类型
  final bool isSignType;

  /// 订单信息
  final String orderInfo;

  /// 错误信息
  final String? errorMessage;

  PayResult({
    required this.type,
    required this.isSuccess,
    required this.orderInfo,
    this.isSignType = false,
    this.errorMessage,
  });
}

/// 统一支付管理器（单例模式）
///
/// 提供统一的支付、分享等功能入口
/// 可以统一管理微信和支付宝两个SDK
class StormyChinaPay {
  /// 单例实例
  static final StormyChinaPay _instance = StormyChinaPay._internal();

  /// 工厂构造函数
  factory StormyChinaPay() => _instance;

  /// 私有构造函数
  StormyChinaPay._internal();

  /// 微信SDK实例
  final WechatSDK _weChatSDK = WechatSDK();

  /// 支付宝SDK实例
  final AlipaySDK _alipaySDK = AlipaySDK();

  /// 微信支付是否启用
  bool _weChatEnabled = true;

  /// 支付宝支付是否启用
  bool _alipayEnabled = true;

  /// 支付事件流合并控制器
  final StreamController<PaymentEvent> _paymentController =
      StreamController<PaymentEvent>.broadcast();

  /// 分享事件流合并控制器（微信分享）
  final StreamController<ShareEvent> _shareController =
      StreamController<ShareEvent>.broadcast();

  /// 授权事件流合并控制器
  final StreamController<AuthEvent> _authController =
      StreamController<AuthEvent>.broadcast();

  /// 支付事件流（聚合所有支付事件）
  Stream<PaymentEvent> get paymentStream => _paymentController.stream;

  /// 分享事件流（聚合所有分享事件，仅微信）
  Stream<ShareEvent> get shareStream => _shareController.stream;

  /// 授权事件流（聚合所有授权事件）
  Stream<AuthEvent> get authStream => _authController.stream;

  /// 初始化微信SDK
  ///
  /// [config] 配置信息，如果为 null 则使用默认配置
  Future<void> initWeChat([WechatConfig? config]) async {
    await _weChatSDK.init(config);
    _setupWeChatListeners();
  }

  /// 初始化支付宝SDK
  ///
  /// [config] 配置信息，如果为 null 则使用默认配置
  Future<void> initAlipay([AlipayConfig? config]) async {
    await _alipaySDK.init(config);
    _setupAlipayListeners();
  }

  /// 同时初始化所有SDK
  ///
  /// [weChatConfig] 微信配置
  /// [alipayConfig] 支付宝配置
  Future<void> initAll({
    WechatConfig? weChatConfig,
    AlipayConfig? alipayConfig,
  }) async {
    if (weChatConfig != null || _weChatEnabled) {
      await initWeChat(weChatConfig);
    }
    if (alipayConfig != null || _alipayEnabled) {
      await initAlipay(alipayConfig);
    }
  }

  /// 设置微信事件监听
  void _setupWeChatListeners() {
    _weChatSDK.paymentStream.listen((event) {
      _paymentController.add(event);
    });

    _weChatSDK.shareStream.listen((event) {
      _shareController.add(event);
    });

    _weChatSDK.authStream.listen((event) {
      _authController.add(event);
    });
  }

  /// 设置支付宝事件监听
  void _setupAlipayListeners() {
    _alipaySDK.paymentStream.listen((event) {
      _paymentController.add(event);
    });

    _alipaySDK.authStream.listen((event) {
      _authController.add(event);
    });
  }

  /// 启用/禁用微信支付
  ///
  /// [enabled] 是否启用
  void setWeChatEnabled(bool enabled) {
    _weChatEnabled = enabled;
    StormyLog.i('StormyChinaPay: 微信支付 ${enabled ? "已启用" : "已禁用"}');
  }

  /// 启用/禁用支付宝支付
  ///
  /// [enabled] 是否启用
  void setAlipayEnabled(bool enabled) {
    _alipayEnabled = enabled;
    StormyLog.i('StormyChinaPay: 支付宝支付 ${enabled ? "已启用" : "已禁用"}');
  }

  /// 检查微信支付是否启用
  bool get isWeChatEnabled => _weChatEnabled;

  /// 检查支付宝支付是否启用
  bool get isAlipayEnabled => _alipayEnabled;

  /// 统一支付入口
  ///
  /// [type] 支付类型
  /// [orderInfo] 订单信息
  /// [weChatPayment] 微信支付信息（仅当 type 为 weChat 时需要）
  /// [isAuth] 支付宝支付 是否为授权支付
  ///
  /// 返回 [PayResult] 支付结果
  Future<PayResult> pay({
    required SDKPaymentType type,
    required String orderInfo,
    Payment? weChatPayment,
    bool isAuth = false,
  }) async {
    if (type == SDKPaymentType.weChat) {
      if (!_weChatEnabled) {
        return PayResult(
          type: type,
          isSuccess: false,
          orderInfo: orderInfo,
          errorMessage: '微信支付已禁用',
        );
      }

      if (weChatPayment == null) {
        return PayResult(
          type: type,
          isSuccess: false,
          orderInfo: orderInfo,
          errorMessage: '微信支付需要提供 Payment 参数',
        );
      }

      final result = await _weChatSDK.pay(weChatPayment, orderInfo);
      return PayResult(
        type: type,
        isSuccess: result,
        orderInfo: orderInfo,
        errorMessage: result ? null : '微信支付请求失败',
      );
    } else if (type == SDKPaymentType.alipay) {
      if (!_alipayEnabled) {
        return PayResult(
          type: type,
          isSuccess: false,
          orderInfo: orderInfo,
          errorMessage: '支付宝支付已禁用',
        );
      }

      final result = await _alipaySDK.pay(orderInfo, isAuth: isAuth);
      return PayResult(
        type: type,
        isSuccess: result,
        orderInfo: orderInfo,
        errorMessage: result ? null : '支付宝支付失败',
      );
    } else {
      return PayResult(
        type: type,
        isSuccess: false,
        orderInfo: orderInfo,
        errorMessage: '不支持的支付类型',
      );
    }
  }

  /// 检查微信是否安装
  Future<bool> isWeChatInstalled() async {
    try {
      final fluwx = Fluwx();
      return await fluwx.isWeChatInstalled;
    } catch (e) {
      StormyLog.e(
        'StormyChinaPay.isWeChatInstalled: 检查失败',
        extra: {'error': e.toString()},
      );
      return false;
    }
  }

  /// 检查支付宝是否安装
  Future<bool> isAlipayInstalled() async {
    try {
      final tobias = Tobias();
      return await tobias.isAliPayInstalled;
    } catch (e) {
      StormyLog.e(
        'StormyChinaPay.isAlipayInstalled: 检查失败',
        extra: {'error': e.toString()},
      );
      return false;
    }
  }

  /// 统一分享图片
  ///
  /// [image] 要分享的图片文件
  /// [platform] 分享平台，默认为微信
  /// [scene] 微信分享场景（仅当 platform 为 weChat 时有效）
  ///
  /// 返回 [bool] 分享是否成功
  Future<bool> shareImage(
    XFile image, {
    SharePlatform platform = SharePlatform.weChat,
    WeChatScene? scene,
  }) async {
    if (platform == SharePlatform.weChat) {
      return await _weChatSDK.shareImage(
        image,
        scene: scene ?? WeChatScene.session,
      );
    } else if (platform == SharePlatform.qq) {
      return false;
    } else {
      StormyLog.w('StormyChinaPay.shareImage: 不支持的分享平台');
      return false;
    }
  }

  /// 一次性监听支付事件
  ///
  /// [callback] 回调函数，收到第一个事件后自动取消订阅
  /// 返回 [StreamSubscription] 订阅对象
  StreamSubscription<PaymentEvent> listenPaymentOnce(
    void Function(PaymentEvent) callback,
  ) {
    late StreamSubscription<PaymentEvent> subscription;
    subscription = paymentStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听分享事件
  StreamSubscription<ShareEvent> listenShareOnce(
    void Function(ShareEvent) callback,
  ) {
    late StreamSubscription<ShareEvent> subscription;
    subscription = shareStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听授权事件
  StreamSubscription<AuthEvent> listenAuthOnce(
    void Function(AuthEvent) callback,
  ) {
    late StreamSubscription<AuthEvent> subscription;
    subscription = authStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 获取微信SDK实例（用于直接访问微信SDK的特定功能）
  WechatSDK get weChatSDK => _weChatSDK;

  /// 获取支付宝SDK实例（用于直接访问支付宝SDK的特定功能）
  AlipaySDK get alipaySDK => _alipaySDK;

  /// 释放资源
  Future<void> dispose() async {
    await _weChatSDK.dispose();
    await _alipaySDK.dispose();
    await _paymentController.close();
    await _shareController.close();
    await _authController.close();
    StormyLog.i('StormyChinaPay: 资源已释放');
  }
}
