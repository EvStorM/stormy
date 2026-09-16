import 'dart:async';

import 'package:stormy_core/stormy_core.dart';
import 'package:stormy_platform/stormy_platform.dart';
import 'package:tobias/tobias.dart';

import '../models/payment_event.dart';
import 'alipay_config.dart';
import 'alipay_events.dart';

class AlipaySDK {
  static AlipaySDK? _instance;
  factory AlipaySDK() => _instance ??= AlipaySDK.withAdapter(Tobias());
  AlipaySDK.withAdapter(this.tobias, {Future<bool> Function(Uri)? launch})
    : _launch = launch ?? launchUrl;

  final Tobias tobias;
  final Future<bool> Function(Uri) _launch;
  AlipayConfig? _config;
  bool _initialized = false;
  bool _disposed = false;
  String? _activeOrder;
  Future<void>? _disposal;
  void Function(AppLifecycleStatus)? _lifecycleCallback;
  final _paymentController = StreamController<AlipayPaymentEvent>.broadcast();
  final _authController = StreamController<AlipayAuthEvent>.broadcast();

  Stream<AlipayPaymentEvent> get paymentStream => _paymentController.stream;
  Stream<AlipayAuthEvent> get authStream => _authController.stream;

  void _checkActive() {
    if (_disposed) throw StateError('AlipaySDK 已销毁，请获取新实例');
  }

  Future<void> init([AlipayConfig? config]) async {
    _checkActive();
    if (_initialized) return;
    _config = config ?? AlipayConfig.defaultConfig();
    _initialized = true;
  }

  void _emit(
    String order,
    PayStatus status, {
    bool isSignType = false,
    String? code,
    String? message,
  }) {
    if (_disposed) return;
    _paymentController.add(
      AlipayPaymentEvent(
        orderInfo: order,
        status: status,
        isSignType: isSignType,
        resultStatus: code,
        errorCode: status == PayStatus.failed ? code : null,
        errorMessage: message,
      ),
    );
  }

  /// Platform progress only; launching a signing page does not confirm a payment.
  Future<PayStatus> pay(String orderInfo, {bool isAuth = false}) async {
    _checkActive();
    if (!_initialized) throw StateError('请先初始化支付宝 SDK');
    if (orderInfo.isEmpty) throw ArgumentError.value(orderInfo, 'orderInfo');
    if (_activeOrder != null) throw StateError('支付宝已有待处理支付');
    _activeOrder = orderInfo;
    var waitingForResume = false;
    try {
      final installed = await tobias.isAliPayInstalled;
      _checkActive();
      if (!installed) {
        _emit(
          orderInfo,
          PayStatus.failed,
          code: 'NOT_INSTALLED',
          message: '请安装支付宝',
        );
        return PayStatus.failed;
      }
      if (isAuth) {
        // Register before opening the other app so a fast resume is not lost.
        _lifecycleCallback = (status) {
          if (_disposed ||
              status != AppLifecycleStatus.resumed ||
              _activeOrder != orderInfo)
            return;
          _removeLifecycleListener();
          _activeOrder = null;
          _emit(
            orderInfo,
            PayStatus.pending,
            isSignType: true,
            message: '请向服务端查询签约结果',
          );
        };
        AppLifecycleManager.instance.addListener(_lifecycleCallback!);
        final launched = await _launch(
          Uri.parse(
            'alipays://platformapi/startapp?appId=${_config!.authAppId}&appClearTop=false&startMultApp=YES&sign_params=${Uri.encodeComponent(orderInfo)}',
          ),
        );
        _checkActive();
        if (!launched) {
          _removeLifecycleListener();
          _emit(
            orderInfo,
            PayStatus.failed,
            isSignType: true,
            code: 'OPEN_URL_ERROR',
          );
          return PayStatus.failed;
        }
        waitingForResume = _activeOrder != null;
        return PayStatus.launched;
      }
      final response = await tobias.pay(
        orderInfo,
        universalLink: _config!.universalLink,
      );
      _checkActive();
      final code = response['resultStatus']?.toString();
      final status = switch (code) {
        '9000' => PayStatus.platformSucceeded,
        '6001' => PayStatus.cancelled,
        '8000' || '6004' => PayStatus.pending,
        _ => PayStatus.failed,
      };
      _emit(
        orderInfo,
        status,
        code: code,
        message: response['memo']?.toString(),
      );
      return status;
    } catch (error) {
      _checkActive();
      _removeLifecycleListener();
      _emit(
        orderInfo,
        PayStatus.failed,
        isSignType: isAuth,
        code: 'EXCEPTION',
        message: error.toString(),
      );
      return PayStatus.failed;
    } finally {
      if (!waitingForResume && _activeOrder == orderInfo) _activeOrder = null;
    }
  }

  Future<bool> auth(String orderInfo) async {
    _checkActive();
    if (!_initialized) throw StateError('请先初始化支付宝 SDK');
    if (orderInfo.isEmpty) throw ArgumentError.value(orderInfo, 'orderInfo');
    try {
      final result = await tobias.auth(orderInfo);
      _checkActive();
      final success = result['resultStatus']?.toString() == '9000';
      _authController.add(
        AlipayAuthEvent(
          isSuccess: success,
          orderInfo: orderInfo,
          authInfo: result['result']?.toString(),
          errorCode: success ? null : result['resultStatus']?.toString(),
        ),
      );
      return success;
    } catch (error) {
      _checkActive();
      _authController.add(
        AlipayAuthEvent(
          isSuccess: false,
          orderInfo: orderInfo,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  StreamSubscription<AlipayPaymentEvent> listenPaymentOnce(
    void Function(AlipayPaymentEvent) callback,
  ) {
    _checkActive();
    return paymentStream.take(1).listen(callback);
  }

  StreamSubscription<AlipayAuthEvent> listenAuthOnce(
    void Function(AlipayAuthEvent) callback,
  ) {
    _checkActive();
    return authStream.take(1).listen(callback);
  }

  void _removeLifecycleListener() {
    final callback = _lifecycleCallback;
    if (callback != null) AppLifecycleManager.instance.removeListener(callback);
    _lifecycleCallback = null;
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    _initialized = false;
    _activeOrder = null;
    if (identical(_instance, this)) _instance = null;
    _removeLifecycleListener();
    await Future.wait([_paymentController.close(), _authController.close()]);
  }
}
