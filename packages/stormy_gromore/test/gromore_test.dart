import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_gromore/stormy_gromore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel(
    'stormy_gromore_test/methods',
  );
  const EventChannel eventChannel = EventChannel(
    'stormy_gromore_test/events',
  );
  final List<MethodCall> calls = <MethodCall>[];
  String preloadResult = 'requested';

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    preloadResult = 'requested';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'loadRewarded':
          return (call.arguments as Map<Object?, Object?>)['requestId'];
        case 'showRewarded':
          return true;
        case 'preloadAds':
          return preloadResult;
        case 'disposeAd':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('初始化和加载请求均把使用参数从 Flutter 发送给原生', () async {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    await gromore.initialize(
      const GromoreConfig(
        appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
        appName: 'example',
        rewardCallbackRetention: Duration(milliseconds: 6500),
      ),
    );
    final String requestId = await gromore.loadRewarded(
      const GromoreRewardedRequest(
        slotId: 'rewarded-slot',
        userId: 'user-1',
        customData: '{"lesson":1}',
      ),
    );

    expect(gromore.isInitialized, isTrue);
    expect(calls.map((MethodCall call) => call.method), <String>[
      'initialize',
      'loadRewarded',
    ]);
    final Map<Object?, Object?> initArguments =
        calls.first.arguments! as Map<Object?, Object?>;
    final Map<Object?, Object?> loadArguments =
        calls.last.arguments! as Map<Object?, Object?>;
    expect(initArguments['appId'], 'android-app');
    expect(initArguments['rewardCallbackRetentionMs'], 6500);
    expect(loadArguments['slotId'], 'rewarded-slot');
    expect(loadArguments['userId'], 'user-1');
    expect(loadArguments['customData'], '{"lesson":1}');
    expect(loadArguments['requestId'], requestId);
  });

  test('同一客户端并发初始化只调用原生一次', () async {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    const GromoreConfig config = GromoreConfig(
      appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
      appName: 'example',
    );

    await Future.wait(<Future<void>>[
      gromore.initialize(config),
      gromore.initialize(config),
    ]);

    expect(
      calls.where((MethodCall call) => call.method == 'initialize'),
      hasLength(1),
    );
  });

  test('预加载把网络策略和完整广告请求参数发送给原生', () async {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    await gromore.initialize(
      const GromoreConfig(
        appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
        appName: 'example',
      ),
    );

    final GromorePreloadResult value = await gromore.preloadAds(
      const GromorePreloadConfig(
        network: GromorePreloadNetwork.any,
        interval: Duration(seconds: 3),
        concurrent: 4,
        items: <GromorePreloadItem>[
          GromorePreloadItem.rewarded(
            GromoreRewardedRequest(
              slotId: 'rewarded-slot',
              userId: 'user-1',
            ),
          ),
          GromorePreloadItem.feed(
            GromoreFeedRequest(
              slotId: 'feed-slot',
              width: 360,
              height: 300,
              muted: true,
            ),
          ),
        ],
      ),
    );

    expect(value, GromorePreloadResult.requested);
    final MethodCall call = calls.last;
    expect(call.method, 'preloadAds');
    final Map<Object?, Object?> arguments =
        call.arguments! as Map<Object?, Object?>;
    expect(arguments['network'], 'any');
    expect(arguments['intervalSeconds'], 3);
    expect(arguments['concurrent'], 4);
    final List<Object?> items = arguments['items']! as List<Object?>;
    final Map<Object?, Object?> rewardRequest = (items.first!
        as Map<Object?, Object?>)['request']! as Map<Object?, Object?>;
    final Map<Object?, Object?> feedRequest = (items.last!
        as Map<Object?, Object?>)['request']! as Map<Object?, Object?>;
    expect(rewardRequest['userId'], 'user-1');
    expect(feedRequest['width'], 360);
    expect(feedRequest['muted'], isTrue);
  });

  test('预加载透传原生网络跳过结果', () async {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
    await gromore.initialize(
      const GromoreConfig(
        appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
        appName: 'example',
      ),
    );
    preloadResult = 'skippedNotWifi';

    expect(
      await gromore.preloadAds(
        const GromorePreloadConfig(
          items: <GromorePreloadItem>[
            GromorePreloadItem.interstitial(
              GromoreInterstitialRequest(slotId: 'interstitial-slot'),
            ),
          ],
        ),
      ),
      GromorePreloadResult.skippedNotWifi,
    );
  });

  test('未初始化时拒绝加载广告', () {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    expect(
      () => gromore.loadRewarded(
        const GromoreRewardedRequest(slotId: 'rewarded-slot'),
      ),
      throwsStateError,
    );
  });

  test('未初始化时拒绝预加载广告', () async {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    await expectLater(
      gromore.preloadAds(
        const GromorePreloadConfig(
          items: <GromorePreloadItem>[
            GromorePreloadItem.splash(
              GromoreSplashRequest(slotId: 'splash-slot'),
            ),
          ],
        ),
      ),
      throwsStateError,
    );
  });

  test('只允许为平台视图广告生成 requestId', () {
    final StormyGromore gromore = StormyGromore(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    expect(
      gromore.createViewRequestId(GromoreAdType.banner),
      startsWith('banner-'),
    );
    expect(
      () => gromore.createViewRequestId(GromoreAdType.rewarded),
      throwsArgumentError,
    );
  });
}
