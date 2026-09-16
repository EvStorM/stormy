import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stormy_gromore/stormy_gromore.dart';

void main() {
  group('GromoreConfig', () {
    test('按目标平台选择 App ID，并默认拒绝隐私能力', () {
      const GromoreConfig config = GromoreConfig(
        appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
        appName: 'example',
      );

      final Map<String, Object> android = config.toMap(
        platform: TargetPlatform.android,
      );
      final Map<String, Object> ios = config.toMap(
        platform: TargetPlatform.iOS,
      );
      final Map<Object?, Object?> privacy =
          android['privacy']! as Map<Object?, Object?>;

      expect(android['appId'], 'android-app');
      expect(ios['appId'], 'ios-app');
      expect(android['rewardCallbackRetentionMs'], 6000);
      expect(ios['rewardCallbackRetentionMs'], 6000);
      expect(privacy['canUseAndroidId'], isFalse);
      expect(privacy['canUseOaid'], isFalse);
      expect(privacy['canUseIdfa'], isFalse);
      expect(privacy['canUseIdfv'], isFalse);
      expect(privacy['canUseStorageSize'], isFalse);
      expect(privacy['allowUploadDeviceInfo'], isFalse);
      expect(privacy['limitPersonalAds'], isTrue);
      expect(privacy['limitProgrammaticAds'], isTrue);
      expect(privacy['forbidCaid'], isTrue);
    });

    test('拒绝空 App ID 和空应用名', () {
      expect(
        () => const GromoreConfig(
          appIds: GromoreAppIds(android: '', ios: 'ios-app'),
          appName: 'example',
        ).toMap(platform: TargetPlatform.android),
        throwsArgumentError,
      );
      expect(
        () => const GromoreConfig(
          appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
          appName: '',
        ).toMap(platform: TargetPlatform.iOS),
        throwsArgumentError,
      );
    });

    test('序列化自定义奖励回调保留期并拒绝非法值', () {
      const GromoreConfig config = GromoreConfig(
        appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
        appName: 'example',
        rewardCallbackRetention: Duration(milliseconds: 6500),
      );

      expect(
        config.toMap(platform: TargetPlatform.android),
        containsPair('rewardCallbackRetentionMs', 6500),
      );
      expect(
        () => const GromoreConfig(
          appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
          appName: 'example',
          rewardCallbackRetention: Duration.zero,
        ).toMap(platform: TargetPlatform.android),
        throwsArgumentError,
      );
      expect(
        () => const GromoreConfig(
          appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
          appName: 'example',
          rewardCallbackRetention: Duration(microseconds: 1),
        ).toMap(platform: TargetPlatform.android),
        throwsArgumentError,
      );
      expect(
        () => const GromoreConfig(
          appIds: GromoreAppIds(android: 'android-app', ios: 'ios-app'),
          appName: 'example',
          rewardCallbackRetention: Duration(milliseconds: 0x80000000),
        ).toMap(platform: TargetPlatform.android),
        throwsArgumentError,
      );
    });
  });

  group('广告请求', () {
    test('激励参数完整序列化且不发送空值', () {
      const GromoreRewardedRequest request = GromoreRewardedRequest(
        slotId: 'rewarded-slot',
        orientation: GromoreAdOrientation.horizontal,
        userId: 'user-1',
        rewardName: '能量',
        rewardAmount: 2,
      );

      expect(request.toMap(), <String, Object>{
        'slotId': 'rewarded-slot',
        'muted': false,
        'orientation': 1,
        'useSurfaceView': true,
        'bidNotify': false,
        'userId': 'user-1',
        'rewardName': '能量',
        'rewardAmount': 2,
      });
    });

    test('视图广告拒绝非正数尺寸', () {
      expect(
        () => const GromoreBannerRequest(
          slotId: 'banner-slot',
          width: 0,
          height: 50,
        ).toMap(),
        throwsArgumentError,
      );
    });
  });

  group('GromorePreloadConfig', () {
    test('完整序列化四种官方支持的预加载广告', () {
      const GromorePreloadConfig config = GromorePreloadConfig(
        network: GromorePreloadNetwork.any,
        interval: Duration(seconds: 4),
        concurrent: 3,
        items: <GromorePreloadItem>[
          GromorePreloadItem.splash(
            GromoreSplashRequest(slotId: 'splash-slot', autoShow: false),
          ),
          GromorePreloadItem.rewarded(
            GromoreRewardedRequest(
              slotId: 'rewarded-slot',
              userId: 'user-1',
              customData: '{"lesson":1}',
            ),
          ),
          GromorePreloadItem.interstitial(
            GromoreInterstitialRequest(slotId: 'interstitial-slot'),
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
      );

      final Map<String, Object> value = config.toMap();
      final List<Object?> items = value['items']! as List<Object?>;

      expect(value['network'], 'any');
      expect(value['intervalSeconds'], 4);
      expect(value['concurrent'], 3);
      expect(
        items.map(
          (Object? item) => (item! as Map<Object?, Object?>)['adType'],
        ),
        <String>['splash', 'rewarded', 'interstitial', 'feed'],
      );
      final Map<Object?, Object?> rewarded = (items[1]!
          as Map<Object?, Object?>)['request']! as Map<Object?, Object?>;
      final Map<Object?, Object?> feed = (items[3]!
          as Map<Object?, Object?>)['request']! as Map<Object?, Object?>;
      expect(rewarded['customData'], '{"lesson":1}');
      expect(feed['width'], 360);
      expect(feed['muted'], isTrue);
    });

    test('默认只在 WiFi 下以官方默认间隔和并发数提交', () {
      const GromorePreloadConfig config = GromorePreloadConfig(
        items: <GromorePreloadItem>[
          GromorePreloadItem.rewarded(
            GromoreRewardedRequest(slotId: 'rewarded-slot'),
          ),
        ],
      );

      expect(config.toMap(), containsPair('network', 'wifiOnly'));
      expect(config.toMap(), containsPair('intervalSeconds', 2));
      expect(config.toMap(), containsPair('concurrent', 2));
    });

    test('拒绝空列表、超过 20 项和重复广告位', () {
      expect(
        () => const GromorePreloadConfig(items: <GromorePreloadItem>[]).toMap(),
        throwsArgumentError,
      );
      expect(
        () => GromorePreloadConfig(
          items: List<GromorePreloadItem>.generate(
            21,
            (int index) => GromorePreloadItem.rewarded(
              GromoreRewardedRequest(slotId: 'rewarded-$index'),
            ),
          ),
        ).toMap(),
        throwsArgumentError,
      );
      expect(
        () => const GromorePreloadConfig(
          items: <GromorePreloadItem>[
            GromorePreloadItem.rewarded(
              GromoreRewardedRequest(slotId: 'rewarded-slot'),
            ),
            GromorePreloadItem.rewarded(
              GromoreRewardedRequest(slotId: 'rewarded-slot'),
            ),
          ],
        ).toMap(),
        throwsArgumentError,
      );
    });

    test('拒绝越界并发数和非法间隔', () {
      const List<GromorePreloadItem> items = <GromorePreloadItem>[
        GromorePreloadItem.feed(
          GromoreFeedRequest(slotId: 'feed-slot', width: 320, height: 180),
        ),
      ];

      expect(
        () => const GromorePreloadConfig(items: items, concurrent: 0).toMap(),
        throwsArgumentError,
      );
      expect(
        () => const GromorePreloadConfig(
          items: items,
          interval: Duration(milliseconds: 1500),
        ).toMap(),
        throwsArgumentError,
      );
      expect(
        () => const GromorePreloadConfig(
          items: items,
          interval: Duration(seconds: 11),
        ).toMap(),
        throwsArgumentError,
      );
    });

    test('解析原生网络门控结果并拒绝未知值', () {
      expect(
        GromorePreloadResult.fromWire('requested'),
        GromorePreloadResult.requested,
      );
      expect(
        GromorePreloadResult.fromWire('skippedNoNetwork'),
        GromorePreloadResult.skippedNoNetwork,
      );
      expect(
        GromorePreloadResult.fromWire('skippedNotWifi'),
        GromorePreloadResult.skippedNotWifi,
      );
      expect(
        () => GromorePreloadResult.fromWire('loaded'),
        throwsFormatException,
      );
    });
  });

  test('原生事件解析奖励与展示价格字段', () {
    final GromoreAdEvent event = GromoreAdEvent.fromMap(<Object?, Object?>{
      'adType': 'rewarded',
      'event': 'rewardEarned',
      'requestId': 'rewarded-1',
      'ecpm': 128,
      'adnName': 'pangle',
      'rewardValid': true,
      'rewardType': 0,
      'rewardAmount': 1,
      'extra': <Object?, Object?>{'tradeId': 'trade-1'},
    });

    expect(event.adType, GromoreAdType.rewarded);
    expect(event.type, GromoreAdEventType.rewardEarned);
    expect(event.ecpm, '128');
    expect(event.rewardValid, isTrue);
    expect(event.extra['tradeId'], 'trade-1');
  });
}
