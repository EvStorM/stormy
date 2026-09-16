import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluwx/fluwx.dart';
import 'package:tobias/tobias.dart';
import 'package:stormy_core/stormy_core.dart';
import 'package:stormy_china_pay/stormy_china_pay.dart';

class _Cancelable implements FluwxCancelable {
  @override
  void cancel() {}
}

class FakeWeChat implements Fluwx {
  int registrations = 0;
  int payments = 0;
  Completer<bool>? registration;
  final listeners = <WeChatResponseSubscriber>[];
  @override
  Future<bool> registerApi({
    required String appId,
    bool doOnIOS = true,
    bool doOnAndroid = true,
    String? universalLink,
  }) async {
    registrations++;
    return registration == null ? true : await registration!.future;
  }

  @override
  FluwxCancelable addSubscriber(WeChatResponseSubscriber listener) {
    listeners.add(listener);
    return _Cancelable();
  }

  @override
  void removeSubscriber(WeChatResponseSubscriber listener) {
    listeners.remove(listener);
  }

  @override
  Future<bool> pay({required PayType which}) async {
    payments++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAlipay implements Tobias {
  String code = '9000';
  Completer<Map>? response;
  @override
  Future<bool> get isAliPayInstalled async => true;
  @override
  Future<Map> pay(
    String order, {
    AliPayEvn evn = AliPayEvn.online,
    bool showPayLoading = true,
    String? universalLink,
  }) async =>
      response == null ? {'resultStatus': code} : await response!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Payment payment() => Payment(
  appId: 'test',
  partnerId: 'test',
  prepayId: 'test',
  packageValue: 'test',
  nonceStr: 'test',
  timestamp: 1,
  sign: 'test',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent initialization registers once and callbacks are forwarded once',
    () async {
      final adapter = FakeWeChat()..registration = Completer<bool>();
      final sdk = WechatSDK.withAdapter(adapter);
      final manager = StormyChinaPay.withAdapters(
        weChat: sdk,
        alipay: AlipaySDK.withAdapter(FakeAlipay()),
      );
      final events = <PaymentEvent>[];
      final subscription = manager.paymentStream.listen(events.add);
      final first = manager.initWeChat();
      final second = manager.initWeChat();
      adapter.registration!.complete(true);
      await Future.wait([first, second]);
      await manager.initWeChat();
      expect(adapter.registrations, 1);
      expect(adapter.listeners.length, 1);
      final result = await manager.pay(
        type: SDKPaymentType.weChat,
        orderInfo: 'order',
        weChatPayment: payment(),
      );
      expect(result.status, PayStatus.launched);
      expect(result.isSuccess, isFalse);
      await expectLater(
        manager.pay(
          type: SDKPaymentType.weChat,
          orderInfo: 'other',
          weChatPayment: payment(),
        ),
        throwsStateError,
      );
      final callback = adapter.listeners.single;
      callback(WeChatPaymentResponse.fromMap({'type': 5, 'errCode': 0}));
      await Future<void>.delayed(Duration.zero);
      expect(events.single.orderInfo, 'order');
      expect(events.single.status, PayStatus.platformSucceeded);
      await manager.dispose();
      callback(WeChatPaymentResponse.fromMap({'type': 5, 'errCode': 0}));
      expect(adapter.listeners, isEmpty);
      expect(() => sdk.init(), throwsStateError);
      await subscription.cancel();
    },
  );

  test(
    'failed initialization can retry; disposal during init does not subscribe',
    () async {
      final adapter = FakeWeChat()..registration = Completer<bool>();
      final sdk = WechatSDK.withAdapter(adapter);
      final failed = expectLater(sdk.init(), throwsStateError);
      adapter.registration!.complete(false);
      await failed;
      adapter.registration = Completer<bool>();
      final disposed = expectLater(sdk.init(), throwsStateError);
      await sdk.dispose();
      adapter.registration!.complete(true);
      await disposed;
      expect(adapter.listeners, isEmpty);
      final retryAdapter = FakeWeChat()..registration = Completer<bool>();
      final retry = WechatSDK.withAdapter(retryAdapter);
      final failure = expectLater(retry.init(), throwsStateError);
      retryAdapter.registration!.complete(false);
      await failure;
      retryAdapter.registration = null;
      await retry.init();
      expect(retryAdapter.listeners.length, 1);
      await retry.dispose();
    },
  );

  test('signing resume is pending, never successful, and rejects concurrent orders', () async {
    final sdk = AlipaySDK.withAdapter(FakeAlipay(), launch: (_) async => true);
    await sdk.init();
    final events = <AlipayPaymentEvent>[];
    final subscription = sdk.paymentStream.listen(events.add);
    expect(await sdk.pay('x', isAuth: true), PayStatus.launched);
    await expectLater(sdk.pay('other'), throwsStateError);
    AppLifecycleManager.instance.notifyStatus(AppLifecycleStatus.resumed);
    AppLifecycleManager.instance.notifyStatus(AppLifecycleStatus.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    expect(events.single.status, PayStatus.pending);
    expect(events.single.isSuccess, isFalse);
    await sdk.dispose();
    await subscription.cancel();
  });

  test(
    'Alipay maps cancellation and ignores responses after disposal',
    () async {
      final adapter = FakeAlipay()..code = '6001';
      final sdk = AlipaySDK.withAdapter(adapter);
      await sdk.init();
      expect(await sdk.pay('cancel'), PayStatus.cancelled);
      adapter.response = Completer<Map>();
      final pending = expectLater(sdk.pay('late'), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await sdk.dispose();
      adapter.response!.complete({'resultStatus': '9000'});
      await pending;
    },
  );

  test('default facades can be reacquired after disposal', () async {
    final old = StormyChinaPay();
    await old.dispose();
    final next = StormyChinaPay();
    expect(next, isNot(same(old)));
    await expectLater(old.initAlipay(), throwsStateError);
    await next.initAlipay();
    await next.dispose();
  });
}
