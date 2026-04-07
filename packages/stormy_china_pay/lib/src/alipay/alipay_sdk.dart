import 'dart:async';
import 'dart:convert';

import 'package:stormy_kit/stormy_kit.dart';
import 'package:tobias/tobias.dart';
import 'alipay_config.dart';
import 'alipay_events.dart';

/// 支付宝支付工具类（单例模式）
///
/// 提供支付宝支付和授权功能
/// 使用前需要调用 [init] 方法进行初始化
class AlipaySDK {
  /// 单例实例
  static final AlipaySDK _instance = AlipaySDK._internal();

  /// 工厂构造函数
  factory AlipaySDK() => _instance;

  /// 私有构造函数
  AlipaySDK._internal();

  /// 配置信息
  AlipayConfig? _config;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 支付事件流控制器
  final StreamController<AlipayPaymentEvent> _paymentController =
      StreamController<AlipayPaymentEvent>.broadcast();

  /// 授权事件流控制器
  final StreamController<AlipayAuthEvent> _authController =
      StreamController<AlipayAuthEvent>.broadcast();

  /// 待发送的签约类型支付事件（等待 App 从后台恢复后再发送）
  AlipayPaymentEvent? _pendingSignEvent;

  /// App 生命周期监听回调
  void Function(AppLifecycleStatus)? _lifecycleCallback;

  /// 支付事件流
  Stream<AlipayPaymentEvent> get paymentStream => _paymentController.stream;

  /// 授权事件流
  Stream<AlipayAuthEvent> get authStream => _authController.stream;

  /// 注册 App 生命周期监听，等待 App 恢复后发送待处理的签约事件
  void _listenAppResumedToEmitSignEvent() {
    _lifecycleCallback = (status) {
      StormyLog.i(
        'AlipaySDK.pay: App 生命周期状态 $status',
        extra: {'orderInfo': _pendingSignEvent!.isSignType},
      );
      if (status == AppLifecycleStatus.resumed && _pendingSignEvent != null) {
        StormyLog.i(
          'AlipaySDK.pay: App 已恢复，发送待处理的签约事件',
          extra: {'orderInfo': _pendingSignEvent!.orderInfo.substring(0, 10)},
        );
        _paymentController.add(_pendingSignEvent!);
        _pendingSignEvent = null;
        AppLifecycleManager.instance.removeListener(_lifecycleCallback!);
        _lifecycleCallback = null;
      }
    };
    AppLifecycleManager.instance.addListener(_lifecycleCallback!);
    StormyLog.i('AlipaySDK.pay: 已注册 App 生命周期监听，等待恢复');
  }

  /// 初始化支付宝 SDK
  ///
  /// [config] 配置信息，如果为 null 则使用默认配置
  Future<void> init([AlipayConfig? config]) async {
    if (_isInitialized) {
      StormyLog.w('AlipaySDK.init: 已经初始化，跳过');
      return;
    }

    _config = config ?? AlipayConfig.defaultConfig();
    _isInitialized = true;
    StormyLog.i('AlipaySDK.init: 初始化完成');
  }

  /// 支付宝支付
  ///
  /// [orderInfo] 订单信息，不能为空
  /// [isAuth] 是否为授权支付，默认为 false
  ///
  /// 返回 [bool] 支付是否成功
  Future<bool> pay(String orderInfo, {bool isAuth = false}) async {
    if (!_isInitialized) {
      StormyLog.w('AlipaySDK.pay: 未初始化，请先调用 init()');
      return false;
    }

    if (orderInfo.isEmpty) {
      StormyLog.w('AlipaySDK.pay: orderInfo 不能为空');
      return false;
    }

    try {
      final tobias = Tobias();
      final isInstalled = await tobias.isAliPayInstalled;

      if (!isInstalled) {
        SmartDialog.showToast('请安装支付宝');
        StormyLog.w('AlipaySDK.pay: 支付宝未安装');
        return false;
      }

      if (isAuth) {
        final signParams = Uri.encodeComponent(orderInfo);
        final url =
            'alipays://platformapi/startapp?appId=60000157&appClearTop=false&startMultApp=YES&sign_params=$signParams';

        try {
          final uri = Uri.parse(url);
          final launched = await launchUrl(uri);
          if (!launched) {
            StormyLog.e('AlipaySDK.pay: 无法打开支付宝授权链接');

            final event = AlipayPaymentEvent(
              orderInfo: orderInfo,
              isSuccess: false,
              errorMessage: '无法打开支付宝授权链接',
            );
            _paymentController.add(event);

            return false;
          }

          _pendingSignEvent = AlipayPaymentEvent(
            orderInfo: orderInfo,
            isSuccess: true,
            isSignType: true,
            errorMessage: '授权支付结果需要通过回调获取',
          );
          _listenAppResumedToEmitSignEvent();

          return false;
        } catch (e) {
          StormyLog.e(
            'AlipaySDK.pay: 打开授权链接失败',
            extra: {'error': e.toString()},
          );

          final event = AlipayPaymentEvent(
            orderInfo: orderInfo,
            isSuccess: false,
            errorCode: 'OPEN_URL_ERROR',
            errorMessage: e.toString(),
          );
          _paymentController.add(event);

          return false;
        }
      } else {
        StormyLog.i('AlipaySDK.pay: 发起支付', extra: {'orderInfo': orderInfo});

        final info = await tobias.pay(
          orderInfo,
          universalLink: _config!.universalLink,
        );
        StormyLog.i('AlipaySDK.pay: 支付响应', extra: {'info': info});

        try {
          final Map<String, dynamic> responseMap = Map<String, dynamic>.from(
            info,
          );

          final resultStatus = responseMap['resultStatus'] as String?;
          if (resultStatus == null) {
            StormyLog.e('AlipaySDK.pay: 支付响应缺少 resultStatus');

            final event = AlipayPaymentEvent(
              orderInfo: orderInfo,
              isSuccess: false,
              errorMessage: '支付响应缺少 resultStatus',
            );
            _paymentController.add(event);

            return false;
          }

          final resultStr = responseMap['result'] as String?;
          if (resultStr == null || resultStr.isEmpty) {
            StormyLog.e('AlipaySDK.pay: 支付响应缺少 result');

            final event = AlipayPaymentEvent(
              orderInfo: orderInfo,
              isSuccess: false,
              errorMessage: '支付响应缺少 result',
            );
            _paymentController.add(event);

            return false;
          }

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          final resultInfo =
              result['alipay_trade_app_pay_response'] as Map<String, dynamic>?;

          if (resultInfo == null) {
            StormyLog.e('AlipaySDK.pay: 支付响应缺少 alipay_trade_app_pay_response');

            final event = AlipayPaymentEvent(
              orderInfo: orderInfo,
              isSuccess: false,
              errorMessage: '支付响应缺少 alipay_trade_app_pay_response',
            );
            _paymentController.add(event);

            return false;
          }

          final resultMessage = resultInfo['msg'] as String?;
          StormyLog.i(
            'AlipaySDK.pay: 支付结果',
            extra: {
              'resultStatus': resultStatus,
              'resultMessage': resultMessage,
            },
          );

          final isSuccess =
              resultStatus == '9000' && resultMessage == 'Success';

          final event = AlipayPaymentEvent(
            orderInfo: orderInfo,
            isSuccess: isSuccess,
            resultStatus: resultStatus,
            resultMessage: resultMessage,
            errorCode: isSuccess ? null : resultStatus,
            errorMessage: isSuccess ? null : resultMessage,
          );
          _paymentController.add(event);

          if (isSuccess) {
            StormyLog.i('AlipaySDK.pay: 支付成功');
            return true;
          } else {
            StormyLog.w(
              'AlipaySDK.pay: 支付失败或取消',
              extra: {
                'resultStatus': resultStatus,
                'resultMessage': resultMessage,
              },
            );
            return false;
          }
        } catch (e) {
          StormyLog.e(
            'AlipaySDK.pay: 解析支付响应失败',
            extra: {'error': e.toString(), 'info': info},
          );

          final event = AlipayPaymentEvent(
            orderInfo: orderInfo,
            isSuccess: false,
            errorCode: 'PARSE_ERROR',
            errorMessage: e.toString(),
          );
          _paymentController.add(event);

          return false;
        }
      }
    } catch (e) {
      StormyLog.e('AlipaySDK.pay: 支付过程发生异常', extra: {'error': e.toString()});

      final event = AlipayPaymentEvent(
        orderInfo: orderInfo,
        isSuccess: false,
        errorCode: 'EXCEPTION',
        errorMessage: e.toString(),
      );
      _paymentController.add(event);

      return false;
    }
  }

  /// 支付宝授权
  ///
  /// [orderInfo] 授权订单信息，不能为空
  ///
  /// 返回 [bool] 授权是否成功发起（注意：授权结果需要通过回调获取）
  Future<bool> auth(String orderInfo) async {
    if (!_isInitialized) {
      StormyLog.w('AlipaySDK.auth: 未初始化，请先调用 init()');
      return false;
    }

    if (orderInfo.isEmpty) {
      StormyLog.w('AlipaySDK.auth: orderInfo 不能为空');
      return false;
    }

    try {
      final tobias = Tobias();
      final isInstalled = await tobias.isAliPayInstalled;

      if (!isInstalled) {
        SmartDialog.showToast('请安装支付宝');
        StormyLog.w('AlipaySDK.auth: 支付宝未安装');

        final event = AlipayAuthEvent(
          isSuccess: false,
          errorMessage: '支付宝未安装',
          orderInfo: orderInfo,
        );
        _authController.add(event);

        return false;
      }

      StormyLog.i('AlipaySDK.auth: 发起授权', extra: {'orderInfo': orderInfo});

      await tobias.auth(orderInfo);
      StormyLog.i('AlipaySDK.auth: 授权请求已发送');

      final event = AlipayAuthEvent(isSuccess: true, orderInfo: orderInfo);
      _authController.add(event);

      return true;
    } catch (e) {
      StormyLog.e(
        'AlipaySDK.auth: 授权过程发生异常',
        extra: {'error': e.toString()},
      );

      final event = AlipayAuthEvent(
        isSuccess: false,
        errorCode: 'EXCEPTION',
        errorMessage: e.toString(),
        orderInfo: orderInfo,
      );
      _authController.add(event);

      return false;
    }
  }

  /// 一次性监听支付事件
  StreamSubscription<AlipayPaymentEvent> listenPaymentOnce(
    void Function(AlipayPaymentEvent) callback,
  ) {
    late StreamSubscription<AlipayPaymentEvent> subscription;
    subscription = paymentStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 一次性监听授权事件
  StreamSubscription<AlipayAuthEvent> listenAuthOnce(
    void Function(AlipayAuthEvent) callback,
  ) {
    late StreamSubscription<AlipayAuthEvent> subscription;
    subscription = authStream.listen((event) {
      callback(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_lifecycleCallback != null) {
      AppLifecycleManager.instance.removeListener(_lifecycleCallback!);
      _lifecycleCallback = null;
    }
    _pendingSignEvent = null;
    await _paymentController.close();
    await _authController.close();
    _isInitialized = false;
    StormyLog.i('AlipaySDK: 资源已释放');
  }
}
