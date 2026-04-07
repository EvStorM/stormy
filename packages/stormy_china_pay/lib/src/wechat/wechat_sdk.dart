import 'dart:async';
import 'dart:io';

import 'package:fluwx/fluwx.dart';
import 'package:stormy_kit/stormy_kit.dart';
import 'wechat_config.dart';
import 'wechat_events.dart';

/// 微信 SDK 工具类（单例模式）
///
/// 提供微信支付、分享、小程序等功能
/// 使用前需要调用 [init] 方法进行初始化
class WechatSDK {
  /// 单例实例
  static final WechatSDK _instance = WechatSDK._internal();

  /// 工厂构造函数
  factory WechatSDK() => _instance;

  /// 私有构造函数
  WechatSDK._internal();

  /// 配置信息
  WechatConfig? _config;

  /// 是否已初始化
  bool _isInitialized = false;

  /// Fluwx 实例
  final Fluwx fluwx = Fluwx();

  /// 当前订单信息
  String? _orderInfo;

  /// 支付事件流控制器
  final StreamController<WeChatPaymentEvent> _paymentController =
      StreamController<WeChatPaymentEvent>.broadcast();

  /// 分享事件流控制器
  final StreamController<WeChatShareEvent> _shareController =
      StreamController<WeChatShareEvent>.broadcast();

  /// 小程序启动事件流控制器
  final StreamController<WeChatLaunchMiniProgramEvent> _miniProgramController =
      StreamController<WeChatLaunchMiniProgramEvent>.broadcast();

  /// 授权事件流控制器
  final StreamController<WeChatAuthEvent> _authController =
      StreamController<WeChatAuthEvent>.broadcast();

  /// 支付事件流
  Stream<WeChatPaymentEvent> get paymentStream => _paymentController.stream;

  /// 分享事件流
  Stream<WeChatShareEvent> get shareStream => _shareController.stream;

  /// 小程序启动事件流
  Stream<WeChatLaunchMiniProgramEvent> get miniProgramStream =>
      _miniProgramController.stream;

  /// 授权事件流
  Stream<WeChatAuthEvent> get authStream => _authController.stream;

  /// 初始化微信 SDK
  ///
  /// [config] 配置信息，如果为 null 则使用默认配置
  /// 注册微信 API，初始化 QQ Kit，注册支付回调监听
  Future<void> init([WechatConfig? config]) async {
    if (_isInitialized) {
      StormyLog.i('WechatSDK.init: 已经初始化，跳过');
      return;
    }

    _config = config ?? WechatConfig.defaultConfig();

    try {
      await fluwx.registerApi(
        appId: _config!.appId,
        doOnAndroid: true,
        doOnIOS: true,
        universalLink: _config!.universalLink,
      );

      final isInstalled = await fluwx.isWeChatInstalled;
      StormyLog.i('WechatSDK.init: 微信安装状态');

      await registerPayResponseListener();

      _isInitialized = true;
      StormyLog.i('WechatSDK.init: 初始化完成');
    } catch (e, stackTrace) {
      StormyLog.e('WechatSDK.init: 初始化失败');
      rethrow;
    }
  }

  /// 微信支付
  ///
  /// [payment] 支付信息
  /// [orderInfo] 订单信息
  ///
  /// 返回 [bool] 支付请求是否成功发起
  Future<bool> pay(Payment payment, String orderInfo) async {
    if (!_isInitialized) {
      StormyLog.w('WechatSDK.pay: 未初始化，请先调用 init()');
      return false;
    }

    if (orderInfo.isEmpty) {
      StormyLog.w('WechatSDK.pay: orderInfo 不能为空');
      return false;
    }

    try {
      _orderInfo = orderInfo;
      StormyLog.i('WechatSDK.pay: 发起支付');

      final result = await fluwx.pay(which: payment);
      StormyLog.i('WechatSDK.pay: 支付请求结果');

      return result;
    } catch (e, stackTrace) {
      StormyLog.e('WechatSDK.pay: 支付请求失败');
      return false;
    }
  }

  /// 签约支付（通过小程序）
  ///
  /// [username] 小程序用户名
  /// [path] 小程序路径
  /// [orderInfo] 订单信息
  ///
  /// 返回 [bool] 是否成功打开小程序
  Future<bool> signPay(String username, String path, String orderInfo) async {
    if (!_isInitialized) {
      StormyLog.w('WechatSDK.signPay: 未初始化，请先调用 init()');
      return false;
    }

    if (username.isEmpty) {
      StormyLog.w('WechatSDK.signPay: username 不能为空');
      return false;
    }
    if (path.isEmpty) {
      StormyLog.w('WechatSDK.signPay: path 不能为空');
      return false;
    }
    if (orderInfo.isEmpty) {
      StormyLog.w('WechatSDK.signPay: orderInfo 不能为空');
      return false;
    }

    try {
      _orderInfo = orderInfo;
      StormyLog.i(
        'WechatSDK.signPay: 打开小程序',
        extra: {'username': username, 'path': path, 'orderInfo': orderInfo},
      );

      final result = await fluwx.open(
        target: MiniProgram(username: username, path: path),
      );

      StormyLog.i('WechatSDK.signPay: 打开小程序结果', extra: {'result': result});
      return result;
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.signPay: 打开小程序失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return false;
    }
  }

  /// 支付响应订阅者
  void _paySubscriber(dynamic response) {
    if (response is WeChatPaymentResponse) {
      _handlePaymentResponse(response);
    } else if (response is WeChatShareResponse) {
      _handleShareResponse(response);
    } else if (response is WeChatLaunchMiniProgramResponse) {
      _handleLaunchMiniProgramResponse(response);
    } else if (response is WeChatAuthResponse) {
      _handleAuthResponse(response);
    } else {
      StormyLog.w(
        'WechatSDK._paySubscriber: 未知的响应类型',
        extra: {'response': response},
      );
    }
  }

  /// 处理支付响应
  void _handlePaymentResponse(WeChatPaymentResponse response) {
    final isSuccessful = response.isSuccessful;
    final errCode = response.errCode;
    final errStr = response.errStr;

    final event = WeChatPaymentEvent(
      orderInfo: _orderInfo ?? '',
      isSuccess: isSuccessful,
      errorCode: errCode?.toString(),
      errorMessage: errStr,
    );

    _paymentController.add(event);

    if (isSuccessful) {
      StormyLog.i('WechatSDK: 支付成功', extra: {'orderId': _orderInfo});
    } else {
      StormyLog.w(
        'WechatSDK: 支付失败',
        extra: {'orderId': _orderInfo, 'errCode': errCode, 'errStr': errStr},
      );
    }
  }

  /// 处理分享响应
  void _handleShareResponse(WeChatShareResponse response) {
    final type = response.type;
    final isSuccessful = response.isSuccessful;
    final errCode = response.errCode;
    final errStr = response.errStr;

    final event = WeChatShareEvent(
      type: type.toString(),
      isSuccess: isSuccessful,
      errorCode: errCode?.toString(),
      errorMessage: errStr,
    );

    _shareController.add(event);

    StormyLog.i(
      'WechatSDK: 分享响应',
      extra: {
        'type': type,
        'isSuccessful': isSuccessful,
        'errCode': errCode,
        'errStr': errStr,
      },
    );

    SmartDialog.dismiss();

    if (isSuccessful) {
      SmartDialog.showToast("分享成功");
    } else {
      SmartDialog.showToast(errStr ?? "分享失败");
    }
  }

  /// 处理小程序启动响应
  void _handleLaunchMiniProgramResponse(
    WeChatLaunchMiniProgramResponse response,
  ) {
    final isSuccessful = response.isSuccessful;

    final event = WeChatLaunchMiniProgramEvent(
      orderInfo: _orderInfo,
      isSuccess: isSuccessful,
    );

    _miniProgramController.add(event);

    StormyLog.i(
      'WechatSDK: 小程序启动响应',
      extra: {'orderId': _orderInfo, 'isSuccessful': isSuccessful},
    );
  }

  /// 处理授权响应
  void _handleAuthResponse(WeChatAuthResponse response) {
    final event = WeChatAuthEvent(
      isSuccess: response.isSuccessful,
      errorCode: response.errCode?.toString(),
      errorMessage: response.errStr,
      authInfo: response.toString(),
    );

    _authController.add(event);

    StormyLog.i('WechatSDK: 授权响应', extra: {'response': response.toString()});
  }

  /// 注册支付回调监听
  Future<void> registerPayResponseListener() async {
    try {
      fluwx.addSubscriber(_paySubscriber);
      StormyLog.i('WechatSDK: 支付回调监听已注册');
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.registerPayResponseListener: 注册失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
    }
  }

  /// 移除支付回调监听
  Future<void> removePayResponseListener() async {
    try {
      fluwx.removeSubscriber(_paySubscriber);
      StormyLog.i('WechatSDK: 支付回调监听已移除');
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.removePayResponseListener: 移除失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
    }
  }

  /// 一次性监听支付事件
  StreamSubscription<WeChatPaymentEvent> listenPaymentOnce(
    void Function(WeChatPaymentEvent) callback,
  ) {
    late StreamSubscription<WeChatPaymentEvent> subscription;
    subscription = paymentStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听分享事件
  StreamSubscription<WeChatShareEvent> listenShareOnce(
    void Function(WeChatShareEvent) callback,
  ) {
    late StreamSubscription<WeChatShareEvent> subscription;
    subscription = shareStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听小程序启动事件
  StreamSubscription<WeChatLaunchMiniProgramEvent> listenMiniProgramOnce(
    void Function(WeChatLaunchMiniProgramEvent) callback,
  ) {
    late StreamSubscription<WeChatLaunchMiniProgramEvent> subscription;
    subscription = miniProgramStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听授权事件
  StreamSubscription<WeChatAuthEvent> listenAuthOnce(
    void Function(WeChatAuthEvent) callback,
  ) {
    late StreamSubscription<WeChatAuthEvent> subscription;
    subscription = authStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 分享图片
  ///
  /// [image] 要分享的图片文件
  /// [scene] 分享场景，默认为会话
  ///
  /// 返回 [bool] 分享是否成功
  Future<bool> shareImage(
    XFile image, {
    WeChatScene scene = WeChatScene.session,
  }) async {
    if (!_isInitialized) {
      StormyLog.w('WechatSDK.shareImage: 未初始化，请先调用 init()');
      return false;
    }

    try {
      StormyLog.i(
        'WechatSDK.shareImage: 开始分享图片',
        extra: {'scene': scene.toString()},
      );

      if (Platform.isAndroid) {
        final bytes = await image.readAsBytes();
        final url = await ImageUtils.saveToGallery(
          bytes,
          album: "share_image_${DateTime.now().millisecondsSinceEpoch}.png",
        );

        if (!url.isSuccess) {
          StormyLog.w(
            'WechatSDK.shareImage: 保存图片失败',
            extra: {'error': url.error},
          );
          return false;
        }

        final result = await fluwx.share(
          WeChatShareImageModel(
            WeChatImageToShare(localImagePath: url.data!),
            scene: scene,
          ),
        );

        StormyLog.i(
          'WechatSDK.shareImage: Android 分享结果',
          extra: {'result': result},
        );
        return result;
      } else if (Platform.isIOS) {
        final thumbnail = await ImageUtils.generateThumbnail(
          image,
          maxWidth: 900,
          maxHeight: 1200,
        );
        final thumbData = await ImageUtils.generateThumbnail(image);

        final result = await fluwx.share(
          WeChatShareImageModel(
            WeChatImageToShare(uint8List: thumbnail.data!),
            scene: scene,
            thumbData: thumbData.data!,
          ),
        );

        StormyLog.i('WechatSDK.shareImage: iOS 分享结果', extra: {'result': result});
        return result;
      } else {
        StormyLog.w('WechatSDK.shareImage: 不支持的平台');
        return false;
      }
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.shareImage: 分享图片失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString()},
      );
      return false;
    }
  }

  /// 分享图片 URL
  ///
  /// [imageUrl] 图片 URL 或本地路径
  /// [scene] 分享场景，默认为会话
  ///
  /// 返回 [bool] 分享是否成功
  Future<bool> shareImageUrl(
    String imageUrl, {
    WeChatScene scene = WeChatScene.session,
  }) async {
    if (!_isInitialized) {
      StormyLog.w('WechatSDK.shareImageUrl: 未初始化，请先调用 init()');
      return false;
    }

    if (imageUrl.isEmpty) {
      StormyLog.w('WechatSDK.shareImageUrl: imageUrl 不能为空');
      return false;
    }

    try {
      StormyLog.i(
        'WechatSDK.shareImageUrl: 开始分享图片',
        extra: {'imageUrl': imageUrl, 'scene': scene.toString()},
      );

      final result = await fluwx.share(
        WeChatShareImageModel(
          WeChatImageToShare(localImagePath: imageUrl),
          scene: scene,
        ),
      );

      StormyLog.i('WechatSDK.shareImageUrl: 分享结果', extra: {'result': result});
      return result;
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.shareImageUrl: 分享图片失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString(), 'imageUrl': imageUrl},
      );
      return false;
    }
  }

  /// 打开微信小程序
  ///
  /// [path] 小程序路径
  /// [username] 小程序用户名，如果为空则使用配置的默认值
  ///
  /// 返回 [bool] 是否成功打开小程序
  Future<bool> openMiniProgram(String path, {String? username}) async {
    if (!_isInitialized) {
      StormyLog.w('WechatSDK.openMiniProgram: 未初始化，请先调用 init()');
      return false;
    }

    if (path.isEmpty) {
      StormyLog.w('WechatSDK.openMiniProgram: path 不能为空');
      return false;
    }

    try {
      final programUsername = username ?? _config!.miniProgramUsername;
      StormyLog.i(
        'WechatSDK.openMiniProgram: 打开小程序',
        extra: {'username': programUsername, 'path': path},
      );

      final result = await fluwx.open(
        target: MiniProgram(username: programUsername, path: path),
      );

      StormyLog.i(
        'WechatSDK.openMiniProgram: 打开小程序结果',
        extra: {'result': result},
      );
      return result;
    } catch (e, stackTrace) {
      StormyLog.e(
        'WechatSDK.openMiniProgram: 打开小程序失败',
        stackTrace: stackTrace,
        extra: {'error': e.toString(), 'path': path},
      );
      return false;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await removePayResponseListener();
    await _paymentController.close();
    await _shareController.close();
    await _miniProgramController.close();
    await _authController.close();
    _isInitialized = false;
    StormyLog.i('WechatSDK: 资源已释放');
  }
}
