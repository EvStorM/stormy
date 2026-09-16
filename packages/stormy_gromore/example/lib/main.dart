import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stormy_gromore/stormy_gromore.dart';

const String _androidAppId = String.fromEnvironment('GROMORE_ANDROID_APP_ID');
const String _iosAppId = String.fromEnvironment('GROMORE_IOS_APP_ID');
const String _splashSlotId = String.fromEnvironment('GROMORE_SPLASH_SLOT_ID');
const String _rewardedSlotId = String.fromEnvironment(
  'GROMORE_REWARDED_SLOT_ID',
);
const String _interstitialSlotId = String.fromEnvironment(
  'GROMORE_INTERSTITIAL_SLOT_ID',
);
const String _bannerSlotId = String.fromEnvironment('GROMORE_BANNER_SLOT_ID');
const String _feedSlotId = String.fromEnvironment('GROMORE_FEED_SLOT_ID');
const String _drawSlotId = String.fromEnvironment('GROMORE_DRAW_SLOT_ID');

const GromoreSplashRequest _splashRequest = GromoreSplashRequest(
  slotId: _splashSlotId,
  autoShow: true,
);
const GromoreRewardedRequest _rewardedRequest = GromoreRewardedRequest(
  slotId: _rewardedSlotId,
  userId: 'example-user',
  customData: '{"source":"flutter-example"}',
  rewardName: '能量',
  rewardAmount: 1,
);
const GromoreInterstitialRequest _interstitialRequest =
    GromoreInterstitialRequest(slotId: _interstitialSlotId);
const GromoreFeedRequest _feedRequest = GromoreFeedRequest(
  slotId: _feedSlotId,
  width: 360,
  height: 300,
  muted: true,
);

void main() => runApp(const AdsExampleApp());

class AdsExampleApp extends StatelessWidget {
  const AdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'stormy_gromore example',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const AdsExamplePage(),
  );
}

class AdsExamplePage extends StatefulWidget {
  const AdsExamplePage({super.key});

  @override
  State<AdsExamplePage> createState() => _AdsExamplePageState();
}

class _AdsExamplePageState extends State<AdsExamplePage> {
  final StormyGromore _gromore = StormyGromore.instance;
  StreamSubscription<GromoreAdEvent>? _events;

  bool _privacyAccepted = false;
  bool _initialized = false;
  GromoreTrackingStatus _tracking = GromoreTrackingStatus.notDetermined;
  String _status = '请先完成隐私授权';
  String? _splashId;
  String? _rewardedId;
  String? _interstitialId;
  bool _splashLoading = false;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;
  bool _preloading = false;
  bool _rewardedReady = false;
  bool _interstitialReady = false;
  GromorePreloadNetwork _preloadNetwork = GromorePreloadNetwork.wifiOnly;
  String? _bannerId;
  String? _feedId;
  String? _drawId;

  @override
  void initState() {
    super.initState();
    _events = _gromore.events.listen(_onEvent);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_disposeAdSilently(_splashId));
    unawaited(_disposeAdSilently(_rewardedId));
    unawaited(_disposeAdSilently(_interstitialId));
    super.dispose();
  }

  void _onEvent(GromoreAdEvent event) {
    if (!mounted) return;
    String? requestToDispose;
    setState(() {
      if (event.requestId == _splashId && _isFullScreenTerminal(event.type)) {
        if (event.type == GromoreAdEventType.showFailed) {
          requestToDispose = _splashId;
        }
        _splashId = null;
      }
      if (event.requestId == _rewardedId) {
        if (event.type == GromoreAdEventType.loaded) {
          _rewardedReady = true;
        } else if (event.type == GromoreAdEventType.shown) {
          _rewardedReady = false;
        }
        if (_isFullScreenTerminal(event.type)) {
          if (event.type == GromoreAdEventType.showFailed) {
            requestToDispose = _rewardedId;
          }
          _rewardedReady = false;
          _rewardedId = null;
        }
      }
      if (event.requestId == _interstitialId) {
        if (event.type == GromoreAdEventType.loaded) {
          _interstitialReady = true;
        } else if (event.type == GromoreAdEventType.shown) {
          _interstitialReady = false;
        }
        if (_isFullScreenTerminal(event.type)) {
          if (event.type == GromoreAdEventType.showFailed) {
            requestToDispose = _interstitialId;
          }
          _interstitialReady = false;
          _interstitialId = null;
        }
      }
      if (event.requestId == _bannerId && _isViewTerminal(event.type)) {
        _bannerId = null;
      }
      if (event.requestId == _feedId && _isViewTerminal(event.type)) {
        _feedId = null;
      }
      if (event.requestId == _drawId && _isViewTerminal(event.type)) {
        _drawId = null;
      }
      _status =
          '${event.adType.name}/${event.type.name}'
          '${event.requestId == null ? '' : ' · ${event.requestId}'}'
          '${event.message == null ? '' : ' · ${event.message}'}';
    });
    if (requestToDispose case final String requestId) {
      unawaited(_disposeAdSilently(requestId));
    }
  }

  Future<void> _disposeAdSilently(String? requestId) async {
    if (requestId == null) return;
    try {
      await _gromore.disposeAd(requestId);
    } catch (_) {
      // The native terminal callback may already have released this request.
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _status = '错误：$error');
    }
  }

  Future<void> _requestAtt() => _guard(() async {
    final GromoreTrackingStatus value = await _gromore
        .requestTrackingAuthorization();
    if (mounted) setState(() => _tracking = value);
  });

  Future<void> _initialize() => _guard(() async {
    await _gromore.initialize(
      GromoreConfig(
        appIds: const GromoreAppIds(android: _androidAppId, ios: _iosAppId),
        appName: 'stormy_gromore example',
        debug: true,
        privacy: GromorePrivacyConfig(
          canUseIdfa: _tracking == GromoreTrackingStatus.authorized,
        ),
      ),
    );
    if (mounted) setState(() => _initialized = true);
  });

  Future<void> _loadSplash() async {
    if (_splashLoading || _splashId != null) return;
    setState(() => _splashLoading = true);
    await _guard(() async {
      final String requestId = await _gromore.loadSplash(_splashRequest);
      if (!mounted) {
        await _disposeAdSilently(requestId);
        return;
      }
      setState(() => _splashId = requestId);
    });
    if (mounted) setState(() => _splashLoading = false);
  }

  Future<void> _loadRewarded() async {
    if (_rewardedLoading || _rewardedId != null) return;
    setState(() => _rewardedLoading = true);
    await _guard(() async {
      final String requestId = await _gromore.loadRewarded(_rewardedRequest);
      if (!mounted) {
        await _disposeAdSilently(requestId);
        return;
      }
      setState(() {
        _rewardedId = requestId;
        _rewardedReady = false;
      });
    });
    if (mounted) setState(() => _rewardedLoading = false);
  }

  Future<void> _showRewarded() async {
    final String? requestId = _rewardedId;
    if (requestId == null || !_rewardedReady) return;
    setState(() => _rewardedReady = false);
    try {
      final bool shown = await _gromore.showRewarded(requestId);
      if (!shown) {
        await _disposeAdSilently(requestId);
        if (mounted && _rewardedId == requestId) {
          setState(() => _rewardedId = null);
        }
      }
    } catch (error) {
      if (mounted && _rewardedId == requestId) {
        setState(() {
          _rewardedReady = true;
          _status = '错误：$error';
        });
      }
    }
  }

  Future<void> _loadInterstitial() async {
    if (_interstitialLoading || _interstitialId != null) return;
    setState(() => _interstitialLoading = true);
    await _guard(() async {
      final String requestId = await _gromore.loadInterstitial(
        _interstitialRequest,
      );
      if (!mounted) {
        await _disposeAdSilently(requestId);
        return;
      }
      setState(() {
        _interstitialId = requestId;
        _interstitialReady = false;
      });
    });
    if (mounted) setState(() => _interstitialLoading = false);
  }

  Future<void> _showInterstitial() async {
    final String? requestId = _interstitialId;
    if (requestId == null || !_interstitialReady) return;
    setState(() => _interstitialReady = false);
    try {
      final bool shown = await _gromore.showInterstitial(requestId);
      if (!shown) {
        await _disposeAdSilently(requestId);
        if (mounted && _interstitialId == requestId) {
          setState(() => _interstitialId = null);
        }
      }
    } catch (error) {
      if (mounted && _interstitialId == requestId) {
        setState(() {
          _interstitialReady = true;
          _status = '错误：$error';
        });
      }
    }
  }

  Future<void> _preloadAds() async {
    if (_preloading) return;
    setState(() => _preloading = true);
    await _guard(() async {
      final GromorePreloadResult result = await _gromore.preloadAds(
        GromorePreloadConfig(
          network: _preloadNetwork,
          items: const <GromorePreloadItem>[
            GromorePreloadItem.rewarded(_rewardedRequest),
            GromorePreloadItem.interstitial(_interstitialRequest),
            GromorePreloadItem.feed(_feedRequest),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _status = switch (result) {
          GromorePreloadResult.requested => '预加载请求已提交；后续加载需继续使用相同请求参数',
          GromorePreloadResult.skippedNoNetwork => '当前无可用网络，未提交预加载',
          GromorePreloadResult.skippedNotWifi => '当前不是 WiFi，未提交预加载',
        };
      });
    });
    if (mounted) setState(() => _preloading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GroMore 全广告类型示例')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        CheckboxListTile(
          value: _privacyAccepted,
          title: const Text('用户已同意应用隐私政策'),
          onChanged: (bool? value) {
            setState(() => _privacyAccepted = value ?? false);
          },
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(onPressed: _requestAtt, child: const Text('请求 ATT')),
            FilledButton(
              onPressed: _privacyAccepted && !_initialized ? _initialize : null,
              child: const Text('初始化 GroMore'),
            ),
            FilledButton(
              onPressed: _initialized && !_splashLoading && _splashId == null
                  ? _loadSplash
                  : null,
              child: Text(_splashLoading ? '开屏加载中…' : '加载并展示开屏'),
            ),
            FilledButton(
              onPressed:
                  _initialized && !_rewardedLoading && _rewardedId == null
                  ? _loadRewarded
                  : null,
              child: Text(_rewardedLoading ? '激励视频加载中…' : '加载激励视频'),
            ),
            OutlinedButton(
              onPressed: _rewardedReady ? _showRewarded : null,
              child: const Text('展示激励视频'),
            ),
            FilledButton(
              onPressed:
                  _initialized &&
                      !_interstitialLoading &&
                      _interstitialId == null
                  ? _loadInterstitial
                  : null,
              child: Text(_interstitialLoading ? '插全屏加载中…' : '加载插全屏'),
            ),
            OutlinedButton(
              onPressed: _interstitialReady ? _showInterstitial : null,
              child: const Text('展示插全屏'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: <Widget>[
            DropdownButton<GromorePreloadNetwork>(
              value: _preloadNetwork,
              items: const <DropdownMenuItem<GromorePreloadNetwork>>[
                DropdownMenuItem<GromorePreloadNetwork>(
                  value: GromorePreloadNetwork.wifiOnly,
                  child: Text('仅 WiFi 预加载'),
                ),
                DropdownMenuItem<GromorePreloadNetwork>(
                  value: GromorePreloadNetwork.any,
                  child: Text('任意网络预加载'),
                ),
              ],
              onChanged: !_initialized || _preloading
                  ? null
                  : (GromorePreloadNetwork? value) {
                      if (value != null) {
                        setState(() => _preloadNetwork = value);
                      }
                    },
            ),
            FilledButton.tonal(
              onPressed: _initialized && !_preloading ? _preloadAds : null,
              child: Text(_preloading ? '正在检查网络…' : '预加载常用广告'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(_status),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: !_initialized || _bannerId != null
                  ? null
                  : () => setState(() {
                      _bannerId = _gromore.createViewRequestId(
                        GromoreAdType.banner,
                      );
                    }),
              child: const Text('创建 Banner'),
            ),
            OutlinedButton(
              onPressed: _bannerId == null
                  ? null
                  : () => setState(() => _bannerId = null),
              child: const Text('移除 Banner'),
            ),
          ],
        ),
        if (_bannerId case final String requestId)
          Center(
            child: GromoreBannerView(
              requestId: requestId,
              request: const GromoreBannerRequest(
                slotId: _bannerSlotId,
                width: 320,
                height: 50,
              ),
            ),
          ),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: !_initialized || _feedId != null
                  ? null
                  : () => setState(() {
                      _feedId = _gromore.createViewRequestId(
                        GromoreAdType.feed,
                      );
                    }),
              child: const Text('创建模板信息流'),
            ),
            OutlinedButton(
              onPressed: _feedId == null
                  ? null
                  : () => setState(() => _feedId = null),
              child: const Text('移除信息流'),
            ),
          ],
        ),
        if (_feedId case final String requestId)
          Center(
            child: GromoreFeedView(requestId: requestId, request: _feedRequest),
          ),
        const Divider(height: 32),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: !_initialized || _drawId != null
                  ? null
                  : () => setState(() {
                      _drawId = _gromore.createViewRequestId(
                        GromoreAdType.drawFeed,
                      );
                    }),
              child: const Text('创建模板 Draw'),
            ),
            OutlinedButton(
              onPressed: _drawId == null
                  ? null
                  : () => setState(() => _drawId = null),
              child: const Text('移除 Draw'),
            ),
          ],
        ),
        if (_drawId case final String requestId)
          Center(
            child: GromoreDrawFeedView(
              requestId: requestId,
              request: const GromoreDrawFeedRequest(
                slotId: _drawSlotId,
                width: 360,
                height: 640,
                muted: true,
              ),
            ),
          ),
      ],
    ),
  );
}

bool _isFullScreenTerminal(GromoreAdEventType type) => switch (type) {
  GromoreAdEventType.failed ||
  GromoreAdEventType.renderFailed ||
  GromoreAdEventType.showFailed ||
  GromoreAdEventType.closed ||
  GromoreAdEventType.disposed => true,
  _ => false,
};

bool _isViewTerminal(GromoreAdEventType type) => switch (type) {
  GromoreAdEventType.failed ||
  GromoreAdEventType.renderFailed ||
  GromoreAdEventType.disliked ||
  GromoreAdEventType.closed ||
  GromoreAdEventType.disposed => true,
  _ => false,
};
